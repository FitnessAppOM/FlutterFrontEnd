import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_service.dart';
import '../../services/training/cardio_session_queue.dart';
import 'exercise_feedback_sheet.dart';
import 'exercise_instruction_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../services/training/training_completion_storage.dart';
import '../../services/training/training_progress_storage.dart';
import '../../services/training/training_activity_service.dart';
import '../../consents/consent_manager.dart';
import '../../core/account_storage.dart';
import '../../widgets/cardio/cardio_map.dart';
import '../../screens/training/cardio_achievement_sheet.dart';
import 'package:pedometer/pedometer.dart';

class ExerciseSessionSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Set<String> completedExerciseNames;
  final VoidCallback onFinished;
  final ImageProvider? previewProvider;
  final bool showSessionOnOpen;

  const ExerciseSessionSheet({
    super.key,
    required this.exercise,
    required this.completedExerciseNames,
    required this.onFinished,
    this.previewProvider,
    this.showSessionOnOpen = false,
  });

  @override
  State<ExerciseSessionSheet> createState() => _ExerciseSessionSheetState();
}

class _ExerciseSessionSheetState extends State<ExerciseSessionSheet>
    with WidgetsBindingObserver {
  bool started = false;
  bool submitting = false;
  bool startRecorded = false;
  bool _feedbackHandled = false;
  bool _cardioMapExpanded = false;
  double _cardioDistanceMeters = 0;
  double _cardioSpeedKmh = 0;
  List<CardioPoint> _cardioRoute = const [];
  int? _cardioSteps;
  int? _cardioStartSteps;
  int? _cardioRawSteps;
  int? _cardioPausedAtSteps;
  bool _adjustStepsOnResume = false;
  StreamSubscription<StepCount>? _stepSub;
  bool _showCardioStartButton = true;
  bool _paused = false;
  bool _countdownSessionStarted = false;

  int seconds = 0;
  Timer? timer;
  int? _sessionStartMs;

  final weightCtrl = TextEditingController();
  final setsCtrl = TextEditingController();
  final repsCtrl = TextEditingController();
  List<Map<String, dynamic>> _setRows = [];
  int? _activeSetIndex;
  Timer? _activeSetTimer;
  bool _activeSetTimerRunning = false;
  int _activeSetElapsedSeconds = 0;
  int _activeSetRestSeconds = 0;

  Timer? _restCountdownTimer;
  int _restCountdownRemaining = 0;
  bool _restCountdownActive = false;
  int _restPresetSeconds = 60;

  double rir = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSetRows();
    _prefillFromLastEntry();
    _restoreActiveSession();
    _restoreTimerState();
    if (_shouldAutoShowInstructions()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openInstructionDialog();
      });
    }
    if (_isCardioExercise()) {
      _showCardioStartButton = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _cardioMapExpanded = true);
      });
      Future.delayed(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        setState(() => _showCardioStartButton = true);
      });
    }
  }

  bool get _supportsSetRows =>
      !_isCardioExercise() && widget.exercise.containsKey('set_rows');

  int? _programExerciseId() {
    final raw = widget.exercise['program_exercise_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = (value ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return false;
    return s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 't';
  }

  int _plannedSets() {
    final sets = _toInt(widget.exercise['sets']);
    return sets > 0 ? sets : 1;
  }

  int? _plannedReps() {
    final reps = _toInt(widget.exercise['reps']);
    return reps > 0 ? reps : null;
  }

  int? _plannedRir() {
    final planned = _toInt(widget.exercise['rir'], fallback: 2);
    return planned >= 0 ? planned : null;
  }

  double? _plannedWeight() {
    final compliance = _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);
    return _toDouble(compliance?['weight_used'] ?? widget.exercise['weight_used']);
  }

  List<Map<String, dynamic>> _normalizeSetRows(List<dynamic> rows) {
    final normalized = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final raw = rows[i];
      if (raw is! Map) continue;
      final index = _toInt(raw['set_index'], fallback: i + 1);
      normalized.add({
        "id": raw['id'],
        "set_index": index <= 0 ? i + 1 : index,
        "reps": raw['reps'] == null ? null : _toInt(raw['reps']),
        "rir": raw['rir'] == null ? null : _toInt(raw['rir']),
        "weight_kg": _toDouble(raw['weight_kg']),
        "completed": _toBool(raw['completed']),
        "performed_time_seconds": raw['performed_time_seconds'] == null
            ? null
            : _toInt(raw['performed_time_seconds']),
        "rest_after_seconds": raw['rest_after_seconds'] == null
            ? null
            : _toInt(raw['rest_after_seconds']),
      });
    }
    normalized.sort(
      (a, b) => _toInt(a['set_index']).compareTo(_toInt(b['set_index'])),
    );
    for (var i = 0; i < normalized.length; i++) {
      normalized[i]['set_index'] = i + 1;
    }
    return normalized;
  }

  List<Map<String, dynamic>> _seedSetRowsFromExercise() {
    final raw = widget.exercise['set_rows'];
    if (raw is List && raw.isNotEmpty) {
      final parsed = _normalizeSetRows(raw);
      if (parsed.isNotEmpty) return parsed;
    }
    final sets = _plannedSets();
    final reps = _plannedReps();
    final plannedRir = _plannedRir();
    final weight = _plannedWeight();
    return List.generate(sets, (i) {
      return {
        "id": null,
        "set_index": i + 1,
        "reps": reps,
        "rir": plannedRir,
        "weight_kg": weight,
        "completed": false,
        "performed_time_seconds": null,
        "rest_after_seconds": null,
      };
    });
  }

  void _initializeSetRows() {
    if (!_supportsSetRows) return;
    _setRows = _seedSetRowsFromExercise();
    if (_setRows.isNotEmpty) {
      _activeSetIndex = _defaultSetIndex();
    }
    _refreshSetRowsFromServer();
  }

  Future<void> _refreshSetRowsFromServer() async {
    if (!_supportsSetRows) return;
    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      final rows = await TrainingService.fetchExerciseSets(programExerciseId);
      if (!mounted) return;
      if (rows.isEmpty && _setRows.isNotEmpty) return;
      setState(() {
        _setRows = rows.isEmpty ? _seedSetRowsFromExercise() : _normalizeSetRows(rows);
        _activeSetIndex = _setRows.isEmpty ? null : _defaultSetIndex();
        if (_activeSetIndex != null) {
          _loadActiveSetTimingFromRow(_activeSetIndex!);
        } else {
          _activeSetElapsedSeconds = 0;
          _activeSetRestSeconds = 0;
        }
      });
    } catch (_) {
      // Keep local rows when offline or endpoint temporarily fails.
    }
  }

  int _defaultSetIndex() {
    if (_setRows.isEmpty) return 1;
    final firstPending = _setRows.firstWhere(
      (row) => !_toBool(row['completed']),
      orElse: () => _setRows.first,
    );
    final idx = _toInt(firstPending['set_index'], fallback: 1);
    return idx > 0 ? idx : 1;
  }

  void _ensureActiveSetSelected() {
    if (!_supportsSetRows || _setRows.isEmpty || _activeSetIndex != null) return;
    final idx = _defaultSetIndex();
    if (mounted) {
      setState(() {
        _activeSetIndex = idx;
        _loadActiveSetTimingFromRow(idx);
      });
    } else {
      _activeSetIndex = idx;
      _loadActiveSetTimingFromRow(idx);
    }
  }

  Map<String, dynamic>? _rowBySetIndex(int setIndex) {
    for (final row in _setRows) {
      if (_toInt(row['set_index']) == setIndex) return row;
    }
    return null;
  }

  void _loadActiveSetTimingFromRow(int setIndex) {
    final row = _rowBySetIndex(setIndex);
    _activeSetElapsedSeconds = row == null
        ? 0
        : _toInt(row['performed_time_seconds'], fallback: 0);
    final rowRest = row == null ? 0 : _toInt(row['rest_after_seconds'], fallback: 0);
    if (rowRest > 0) {
      _activeSetRestSeconds = rowRest;
      _restPresetSeconds = rowRest;
    } else {
      _activeSetRestSeconds = _restPresetSeconds;
    }
  }

  Future<void> _saveTimerState() async {
    final peId = _programExerciseId();
    if (peId == null || !_supportsSetRows) return;
    await TrainingProgressStorage.saveExerciseTimerState(peId, {
      'active_set_index': _activeSetIndex,
      'set_elapsed': _activeSetElapsedSeconds,
      'set_running': _activeSetTimerRunning,
      'rest_preset': _restPresetSeconds,
      'rest_countdown_remaining': _restCountdownRemaining,
      'rest_countdown_active': _restCountdownActive,
      'rest_after': _activeSetRestSeconds,
      'started': started,
      'paused': _paused,
      'seconds': seconds,
      'start_ms': _sessionStartMs,
    });
  }

  Future<void> _restoreTimerState() async {
    final peId = _programExerciseId();
    if (peId == null || !_supportsSetRows) return;
    final state = await TrainingProgressStorage.loadExerciseTimerState(peId);
    if (state == null || !mounted) return;
    final wasStarted = state['started'] == true;
    if (!wasStarted) return;

    final savedSetIndex = _toInt(state['active_set_index'] ?? 0);
    final savedElapsed = _toInt(state['set_elapsed'] ?? 0);
    final savedRunning = state['set_running'] == true;
    final savedRestPreset = _toInt(state['rest_preset'] ?? 60, fallback: 60);
    final savedRestRemaining = _toInt(state['rest_countdown_remaining'] ?? 0);
    final savedRestActive = state['rest_countdown_active'] == true;
    final savedRestAfter = _toInt(state['rest_after'] ?? 0);
    final savedPaused = state['paused'] == true;
    final savedSeconds = _toInt(state['seconds'] ?? 0);
    final savedStartMs = state['start_ms'] as int?;

    setState(() {
      started = true;
      _paused = savedPaused;
      _restPresetSeconds = savedRestPreset > 0 ? savedRestPreset : 60;
      if (savedSetIndex > 0) {
        _activeSetIndex = savedSetIndex;
        _activeSetElapsedSeconds = savedElapsed;
        _activeSetRestSeconds = savedRestAfter;
      }
      if (savedPaused) {
        seconds = savedSeconds;
        _sessionStartMs = null;
      } else {
        _sessionStartMs = savedStartMs;
        if (_sessionStartMs != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          seconds = ((now - _sessionStartMs!) / 1000).round();
        } else {
          seconds = savedSeconds;
        }
      }
    });

    if (!savedPaused) {
      _startTimer();
      if (savedRunning && savedSetIndex > 0) {
        _startActiveSetTimer();
      }
      if (savedRestActive && savedRestRemaining > 0) {
        _startRestCountdown(savedRestRemaining);
      }
    }
  }

  String _formatSeconds(int total) {
    final safe = total < 0 ? 0 : total;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _startActiveSetTimer() {
    if (_activeSetTimerRunning) return;
    _activeSetTimerRunning = true;
    _activeSetTimer?.cancel();
    _activeSetTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_activeSetTimerRunning) return;
      setState(() => _activeSetElapsedSeconds++);
    });
  }

  void _pauseActiveSetTimer() {
    _activeSetTimerRunning = false;
    _activeSetTimer?.cancel();
    _activeSetTimer = null;
  }

  Future<void> _persistActiveSetTiming() async {
    final setIndex = _activeSetIndex;
    if (!_supportsSetRows || setIndex == null) return;
    await _upsertSetRow(
      setIndex: setIndex,
      performedTimeSeconds: _activeSetElapsedSeconds,
      restAfterSeconds: _activeSetRestSeconds,
    );
  }

  void _startRestCountdown(int restSeconds) {
    _stopRestCountdown();
    if (restSeconds <= 0) return;
    _restCountdownRemaining = restSeconds;
    _restCountdownActive = true;
    _restCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopRestCountdown();
        return;
      }
      setState(() {
        _restCountdownRemaining--;
        if (_restCountdownRemaining <= 0) {
          _onRestComplete();
        }
      });
    });
    if (mounted) setState(() {});
  }

  void _stopRestCountdown() {
    _restCountdownTimer?.cancel();
    _restCountdownTimer = null;
    _restCountdownActive = false;
    _restCountdownRemaining = 0;
  }

  void _skipRest() {
    _stopRestCountdown();
    if (mounted) setState(() {});
  }

  void _onRestComplete() {
    _stopRestCountdown();
    if (mounted) setState(() {});
  }

  bool _isSetCompleted(int setIndex) {
    final row = _rowBySetIndex(setIndex);
    return row != null && _toBool(row['completed']);
  }

  int? _nextPendingSetIndex() {
    for (final row in _setRows) {
      final idx = _toInt(row['set_index'], fallback: 0);
      if (idx > 0 && !_toBool(row['completed'])) return idx;
    }
    return null;
  }

  Future<void> _finishActiveSet() async {
    final setIndex = _activeSetIndex;
    if (setIndex == null) return;
    _pauseActiveSetTimer();
    final restSeconds = _activeSetRestSeconds;
    await _upsertSetRow(
      setIndex: setIndex,
      completed: true,
      performedTimeSeconds: _activeSetElapsedSeconds,
      restAfterSeconds: restSeconds,
    );
    if (!mounted) return;
    final nextSet = _nextPendingSetIndex();
    setState(() {
      _activeSetIndex = nextSet ?? setIndex;
      _activeSetElapsedSeconds = 0;
      _activeSetRestSeconds = _restPresetSeconds;
    });
  }

  Future<void> _restoreActiveSession() async {
    final session = await TrainingActivityService.getActiveSession();
    if (!mounted || session == null) return;
    final currentName = (widget.exercise['exercise_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final sessionName = (session['name'] ?? '').toString().trim().toLowerCase();
    if (currentName.isEmpty || sessionName != currentName) return;
    final paused = session['paused'] == true;
    if (_isCardioExercise()) {
      final distanceKm = session['distanceKm'] as double?;
      final paceMinKm = session['paceMinKm'] as double?;
      setState(() {
        if (distanceKm != null) {
          _cardioDistanceMeters = distanceKm * 1000.0;
        }
        if (paceMinKm != null && paceMinKm > 0.01) {
          _cardioSpeedKmh = 60.0 / paceMinKm;
        }
      });
    }
    final pausedSeconds = session['pausedSeconds'] as int?;
    _sessionStartMs = paused ? null : session['startMs'] as int?;
    if (paused && pausedSeconds != null) {
      seconds = pausedSeconds;
    } else {
      final startMs = _sessionStartMs;
      if (startMs != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        seconds = ((nowMs - startMs) / 1000).round();
      }
    }
    if (!started) {
      setState(() {
        started = true;
        _paused = paused;
      });
      if (!paused) {
        _startTimer();
        if (_isCardioExercise()) {
          await _startCardioStepsTracking();
        }
      }
    }
  }

  void _syncElapsedFromStart({bool force = false}) {
    if (_paused) return;
    final startMs = _sessionStartMs;
    if (startMs == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((nowMs - startMs) / 1000).round();
    if (force || elapsed != seconds) {
      setState(() => seconds = elapsed);
    }
  }

  void _prefillFromLastEntry() {
    final compliance =
        _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);

    final performedSets =
        compliance?['performed_sets'] ?? widget.exercise['performed_sets'];
    final performedReps =
        compliance?['performed_reps'] ?? widget.exercise['performed_reps'];
    final weightUsed =
        compliance?['weight_used'] ?? widget.exercise['weight_used'];
    final performedRir =
        compliance?['performed_rir'] ?? widget.exercise['performed_rir'];

    if (setsCtrl.text.isEmpty) {
      final text = _valueAsText(performedSets);
      if (text != null) setsCtrl.text = text;
    }
    if (repsCtrl.text.isEmpty) {
      final text = _valueAsText(performedReps);
      if (text != null) repsCtrl.text = text;
    }
    if (weightCtrl.text.isEmpty) {
      final text = _valueAsText(weightUsed);
      if (text != null) weightCtrl.text = text;
    }
    final rirValue = _valueAsDouble(performedRir);
    if (rirValue != null) {
      rir = rirValue.clamp(0, 3);
    }
  }

  Map<String, dynamic>? _extractCompliance(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _valueAsText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      if (value == 0) return null;
      final asInt = value.toInt();
      return (value == asInt) ? asInt.toString() : value.toString();
    }
    if (value is bool) return value ? "1" : null;
    return value.toString();
  }

  double? _valueAsDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    if (value is bool) return value ? 1 : 0;
    return null;
  }

  bool _shouldAutoShowInstructions() {
    final instructions = widget.exercise['instructions'] ?? '';
    if (instructions.toString().trim().isEmpty) return false;
    final rawName = (widget.exercise['exercise_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (rawName.isNotEmpty && widget.completedExerciseNames.contains(rawName)) {
      return false;
    }
    return !_hasExistingEntry(widget.exercise);
  }

  bool _isCardioExercise() {
    String _lower(dynamic v) => (v ?? '').toString().trim().toLowerCase();
    final category = _lower(widget.exercise['category']);
    final exType = _lower(widget.exercise['exercise_type']);
    final animName = _lower(widget.exercise['animation_name']);
    final name = _lower(widget.exercise['exercise_name']);
    return [
          category,
          exType,
          animName,
          name,
        ].any((v) => v.contains('cardio')) ||
        animName.startsWith('cardio -');
  }

  bool _hasExistingEntry(Map<String, dynamic> exercise) {
    final entries = [
      exercise['program_compliance'],
      exercise['compliance'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
      exercise['completed'],
      exercise['is_completed'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
    ];
    return entries.any(_hasMeaningfulValue);
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  void _openInstructionDialog() {
    final instructions = (widget.exercise['instructions'] ?? '').toString();
    if (instructions.trim().isEmpty) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => ExerciseInstructionDialog(
        title: t.translate("training_instructions_title"),
        instructions: instructions,
      ),
    );
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => seconds++);
      if (_isCardioExercise() || seconds % 5 == 0) {
        final sets = _currentSets();
        final reps = _currentReps();
        final isCardio = _isCardioExercise();
        final distanceKm = isCardio ? (_cardioDistanceMeters / 1000.0) : null;
        final paceMinKm = isCardio ? _currentPaceMinPerKm() : null;
        TrainingActivityService.updateSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: sets,
          reps: reps,
          seconds: seconds,
          distanceKm: distanceKm,
          paceMinKm: paceMinKm,
        );
      }
    });
  }

  Future<void> _startCardioStepsTracking() async {
    if (!_isCardioExercise()) return;
    _cardioSteps ??= 0;
    if (mounted) setState(() {});
    _stepSub?.cancel();
    _stepSub = Pedometer.stepCountStream.listen((event) {
      _cardioRawSteps = event.steps;
      if (_adjustStepsOnResume && _cardioPausedAtSteps != null) {
        final pausedDelta = event.steps - (_cardioPausedAtSteps ?? event.steps);
        _cardioStartSteps = (_cardioStartSteps ?? event.steps) + pausedDelta;
        _adjustStepsOnResume = false;
        _cardioPausedAtSteps = null;
      }
      _cardioStartSteps ??= event.steps;
      _cardioSteps = event.steps - (_cardioStartSteps ?? event.steps);
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  void _stopCardioStepsTracking() {
    _stepSub?.cancel();
    _stepSub = null;
  }

  String get _time =>
      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

  double _paceMinPerKm(double speedKmh) {
    if (speedKmh <= 0.1) return 0;
    return 60.0 / speedKmh;
  }

  double _paceMinPerKmFromDistance(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0.001 || durationSeconds <= 0) return 0;
    return (durationSeconds / 60.0) / distanceKm;
  }

  double _currentPaceMinPerKm() {
    return _paceMinPerKm(_cardioSpeedKmh);
  }

  void _mergeIncomingCardioRoute(List<CardioPoint> incoming) {
    if (incoming.isEmpty) return;
    if (_cardioRoute.isEmpty) {
      _cardioRoute = List<CardioPoint>.from(incoming);
      return;
    }
    // Normal case: tracker sends the full accumulated route.
    if (incoming.length >= _cardioRoute.length) {
      _cardioRoute = List<CardioPoint>.from(incoming);
      return;
    }
    // Recovery case: tracker restarted after lifecycle transition and sent
    // a shorter route. Keep existing trace and append new tail points.
    final merged = List<CardioPoint>.from(_cardioRoute);
    for (final point in incoming) {
      final last = merged.last;
      final samePoint =
          last.lat == point.lat &&
          last.lng == point.lng &&
          last.paused == point.paused;
      if (!samePoint) merged.add(point);
    }
    _cardioRoute = merged;
  }

  Future<void> _startExercise() async {
    if (started) {
      if (_paused) {
        setState(() => _paused = false);
        _sessionStartMs ??=
            DateTime.now().millisecondsSinceEpoch - (seconds * 1000);
        _syncElapsedFromStart();
        _startTimer();
        await TrainingActivityService.resumeSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: _currentSets(),
          reps: _currentReps(),
          seconds: seconds,
          distanceKm: _isCardioExercise()
              ? (_cardioDistanceMeters / 1000.0)
              : null,
          paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
        );
      }
      await _startCardioStepsTracking();
      if (_countdownSessionStarted) {
        _countdownSessionStarted = false;
        await TrainingActivityService.resumeSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: _currentSets(),
          reps: _currentReps(),
          seconds: seconds,
          distanceKm: _isCardioExercise()
              ? (_cardioDistanceMeters / 1000.0)
              : null,
          paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
        );
      } else {
        await TrainingActivityService.startSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: _currentSets(),
          reps: _currentReps(),
          seconds: seconds,
          distanceKm: _isCardioExercise()
              ? (_cardioDistanceMeters / 1000.0)
              : null,
          paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
        );
      }
      _ensureActiveSetSelected();
      if (_supportsSetRows && _activeSetIndex != null) {
        _startActiveSetTimer();
      }
      return;
    }
    if (_isCardioExercise()) {
      final hasBg = await ConsentManager.hasBackgroundLocationPermission();
      if (!hasBg) {
        if (mounted) {
          AppToast.show(
            context,
            "Allow 'Always' location to start cardio tracking.",
            type: AppToastType.info,
          );
        }
        return;
      }
    }
    setState(() {
      started = true;
      _paused = false;
    });
    _cardioStartSteps = null;
    _cardioPausedAtSteps = null;
    _adjustStepsOnResume = false;
    _sessionStartMs ??= DateTime.now().millisecondsSinceEpoch;
    _syncElapsedFromStart();
    _startTimer();
    await _startCardioStepsTracking();
    if (_countdownSessionStarted) {
      _countdownSessionStarted = false;
      await TrainingActivityService.resumeSession(
        exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
        sets: _currentSets(),
        reps: _currentReps(),
        seconds: seconds,
        distanceKm: _isCardioExercise()
            ? (_cardioDistanceMeters / 1000.0)
            : null,
        paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
      );
    } else {
      await TrainingActivityService.startSession(
        exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
        sets: _currentSets(),
        reps: _currentReps(),
        seconds: seconds,
        distanceKm: _isCardioExercise()
            ? (_cardioDistanceMeters / 1000.0)
            : null,
        paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
      );
    }
    _ensureActiveSetSelected();

    // Queue start action for sync (non-blocking)
    final rawProgramExerciseId = widget.exercise['program_exercise_id'];
    final int? programExerciseId = rawProgramExerciseId is int
        ? rawProgramExerciseId
        : int.tryParse(rawProgramExerciseId?.toString() ?? '');
    if (programExerciseId != null) {
      try {
        await TrainingService.startExercise(programExerciseId);
        startRecorded = true;
      } catch (e) {
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionStart,
          programExerciseId: programExerciseId,
        );
        startRecorded = false;
      }
    }
    TrainingProgressStorage.recordWorkoutStart();
  }

  Future<void> _startSet(int setIndex) async {
    _stopRestCountdown();
    final previousActive = _activeSetIndex;
    if (previousActive != null && previousActive != setIndex) {
      _pauseActiveSetTimer();
      await _persistActiveSetTiming();
    }
    if (!started || _paused) {
      await _startExercise();
      if (!mounted) return;
    }
    setState(() {
      _activeSetIndex = setIndex;
      _loadActiveSetTimingFromRow(setIndex);
    });
    _startActiveSetTimer();
  }

  Future<void> _onPrimaryExerciseButtonPressed() async {
    if (started) {
      await _finishExercise();
      return;
    }
    await _startExercise();
    if (!mounted) return;
    _ensureActiveSetSelected();
    if (_supportsSetRows && _activeSetIndex != null) {
      await _startSet(_activeSetIndex!);
    }
  }

  void _setRestPreset(int secs) {
    setState(() {
      _restPresetSeconds = secs;
      _activeSetRestSeconds = secs;
    });
  }

  Future<void> _setCustomRestPreset() async {
    final ctrl = TextEditingController(
      text: _restPresetSeconds > 0 ? _restPresetSeconds.toString() : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121727),
        title: const Text("Custom rest (seconds)", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputStyle("Seconds"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final next = int.tryParse(ctrl.text.trim()) ?? 0;
    if (next > 0) _setRestPreset(next);
  }

  List<Map<String, dynamic>> _reindexedRows(List<Map<String, dynamic>> rows) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = Map<String, dynamic>.from(rows[i]);
      row['set_index'] = i + 1;
      out.add(row);
    }
    return out;
  }

  Future<void> _addSetRow() async {
    if (!_supportsSetRows) return;
    final current = List<Map<String, dynamic>>.from(_setRows);
    final nextIndex = current.length + 1;
    final last = current.isNotEmpty ? current.last : null;
    current.add({
      "id": null,
      "set_index": nextIndex,
      "reps": last?['reps'] ?? _plannedReps(),
      "rir": last?['rir'] ?? _plannedRir(),
      "weight_kg": last?['weight_kg'] ?? _plannedWeight(),
      "completed": false,
      "performed_time_seconds": null,
      "rest_after_seconds": null,
    });
    setState(() {
      _setRows = current;
    });

    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      await TrainingService.addExerciseSet(
        programExerciseId: programExerciseId,
        cloneLast: true,
      );
      await _refreshSetRowsFromServer();
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetAdd,
        programExerciseId: programExerciseId,
        data: {"clone_last": true},
      );
    }
  }

  Future<void> _deleteSetRow(int setIndex) async {
    if (!_supportsSetRows) return;
    if (_setRows.length <= 1) return;
    final filtered = _setRows
        .where((row) => _toInt(row['set_index']) != setIndex)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    setState(() {
      _setRows = _reindexedRows(filtered);
      if (_activeSetIndex == setIndex) {
        _pauseActiveSetTimer();
        if (_setRows.isEmpty) {
          _activeSetIndex = null;
          _activeSetElapsedSeconds = 0;
          _activeSetRestSeconds = 0;
        } else {
          _activeSetIndex = setIndex > _setRows.length ? _setRows.length : setIndex;
          _loadActiveSetTimingFromRow(_activeSetIndex!);
        }
      } else if (_activeSetIndex != null && _activeSetIndex! > setIndex) {
        _activeSetIndex = _activeSetIndex! - 1;
      }
    });

    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      await TrainingService.deleteExerciseSet(
        programExerciseId: programExerciseId,
        setIndex: setIndex,
      );
      await _refreshSetRowsFromServer();
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetDelete,
        programExerciseId: programExerciseId,
        data: {"set_index": setIndex},
      );
    }
  }

  Future<void> _upsertSetRow({
    required int setIndex,
    int? reps,
    int? rirValue,
    double? weightKg,
    bool? completed,
    int? performedTimeSeconds,
    int? restAfterSeconds,
  }) async {
    if (!_supportsSetRows) return;
    final next = _setRows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: true);
    final idx = next.indexWhere((row) => _toInt(row['set_index']) == setIndex);
    if (idx == -1) return;
    final updated = next[idx];
    if (reps != null) updated['reps'] = reps;
    if (rirValue != null) updated['rir'] = rirValue;
    if (weightKg != null) updated['weight_kg'] = weightKg;
    if (completed != null) {
      updated['completed'] = completed;
      updated['completed_at'] = completed ? DateTime.now().toIso8601String() : null;
    }
    if (performedTimeSeconds != null) {
      updated['performed_time_seconds'] = performedTimeSeconds;
    }
    if (restAfterSeconds != null) {
      updated['rest_after_seconds'] = restAfterSeconds;
    }
    setState(() {
      _setRows = next;
    });

    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    final payload = <String, dynamic>{
      "set_index": setIndex,
      if (reps != null) "reps": reps,
      if (rirValue != null) "rir": rirValue,
      if (weightKg != null) "weight_kg": weightKg,
      if (completed != null) "completed": completed,
      if (performedTimeSeconds != null)
        "performed_time_seconds": performedTimeSeconds,
      if (restAfterSeconds != null) "rest_after_seconds": restAfterSeconds,
    };
    try {
      await TrainingService.upsertExerciseSet(
        programExerciseId: programExerciseId,
        setIndex: setIndex,
        reps: reps,
        rir: rirValue,
        weightKg: weightKg,
        completed: completed,
        performedTimeSeconds: performedTimeSeconds,
        restAfterSeconds: restAfterSeconds,
      );
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetUpsert,
        programExerciseId: programExerciseId,
        data: payload,
      );
    }
  }

  Future<void> _openSetEditDialog(Map<String, dynamic> row) async {
    final repsCtrl = TextEditingController(
      text: row['reps'] == null ? '' : _toInt(row['reps']).toString(),
    );
    final rirCtrl = TextEditingController(
      text: row['rir'] == null ? '' : _toInt(row['rir']).toString(),
    );
    final weightCtrl = TextEditingController(
      text: row['weight_kg'] == null
          ? ''
          : (_toDouble(row['weight_kg'])?.toString() ?? ''),
    );
    bool done = _toBool(row['completed']);
    final setIndex = _toInt(row['set_index']);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121727),
              title: Text(
                "Set $setIndex",
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle("Weight (kg)"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle("Reps"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rirCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle("RIR"),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: done,
                      onChanged: (v) => setModalState(() => done = v),
                      activeColor: Colors.greenAccent,
                      title: const Text(
                        "Completed",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) return;
    await _upsertSetRow(
      setIndex: setIndex,
      reps: int.tryParse(repsCtrl.text.trim()),
      rirValue: int.tryParse(rirCtrl.text.trim()),
      weightKg: double.tryParse(weightCtrl.text.trim()),
      completed: done,
    );
  }

  Widget _buildSetRowsEditor() {
    final rows = _setRows;
    final int? focusedSetIndex = _activeSetIndex ?? _nextPendingSetIndex();
    final bool focusedCompleted = focusedSetIndex == null
        ? true
        : _isSetCompleted(focusedSetIndex);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Sets",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                "${rows.where((r) => _toBool(r['completed'])).length}/${rows.length} done",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // --- Active set timer (counts UP) ---
          if (_activeSetIndex != null && _activeSetTimerRunning) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2D7CFF).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Color(0xFF2D7CFF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Set $_activeSetIndex",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatSeconds(_activeSetElapsedSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  _CompactButton(
                    label: "Finish Set",
                    color: Colors.greenAccent,
                    onTap: _finishActiveSet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // --- Rest countdown (counts DOWN, user-triggered) ---
          if (_restCountdownActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orangeAccent.withOpacity(0.15),
                    Colors.deepOrange.withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_bottom, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatSeconds(_restCountdownRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _restCountdownRemaining += 30);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text("+30s"),
                  ),
                  _CompactButton(
                    label: "Skip",
                    color: const Color(0xFF2D7CFF),
                    onTap: _skipRest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // --- Rest preset + Start Rest (shown when NOT running set and NOT counting down) ---
          if (_activeSetIndex != null && !_activeSetTimerRunning && !_restCountdownActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.snooze, color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Rest",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _setCustomRestPreset,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit, size: 12, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text(
                              "Custom",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final s in [30, 60, 90, 120])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: s == 120 ? 0 : 6),
                            child: _RestPill(
                              label: "${s}s",
                              active: _restPresetSeconds == s,
                              onTap: () => _setRestPreset(s),
                            ),
                          ),
                        ),
                      if (![30, 60, 90, 120].contains(_restPresetSeconds))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _RestPill(
                              label: "${_restPresetSeconds}s",
                              active: true,
                              onTap: _setCustomRestPreset,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startRestCountdown(_restPresetSeconds),
                      icon: const Icon(Icons.hourglass_top, size: 18),
                      label: Text("Start Rest  ${_formatSeconds(_restPresetSeconds)}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.withOpacity(0.15),
                        foregroundColor: Colors.orangeAccent,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.orangeAccent.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // --- Start Set button (always visible for next pending set) ---
          if (focusedSetIndex != null && !_activeSetTimerRunning) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: focusedCompleted
                    ? null
                    : () => _startSet(focusedSetIndex),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text("Start Set $focusedSetIndex"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7CFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    "SET",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  width: 62,
                  child: Text(
                    "KG",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    "REPS",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "RIR / DONE",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.62),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              "No sets yet.",
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final row = entry.value;
              final setIndex = _toInt(row['set_index']);
              final weight = _toDouble(row['weight_kg']);
              final weightLabel = weight == null
                  ? '-'
                  : weight.toStringAsFixed(
                      weight == weight.roundToDouble() ? 0 : 1,
                    );
              final reps = row['reps'] == null ? '-' : _toInt(row['reps']).toString();
              final rirValue = row['rir'] == null ? '-' : _toInt(row['rir']).toString();
              final done = _toBool(row['completed']);
              final isActive = _activeSetIndex == setIndex;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10263B)
                      : (done
                            ? const Color(0xFF112418)
                            : Colors.black.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2D7CFF)
                        : (done
                              ? Colors.greenAccent.withOpacity(0.35)
                              : Colors.white.withOpacity(0.07)),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openSetEditDialog(row),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            "$setIndex",
                            style: TextStyle(
                              color: done ? Colors.greenAccent : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 62,
                          child: Text(
                            weightLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            reps,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "RIR $rirValue",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (!done)
                                  const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () async {
                                    final wasActive = _activeSetIndex == setIndex;
                                    int restSecs = 0;
                                    if (!done && wasActive) {
                                      _pauseActiveSetTimer();
                                      restSecs = _activeSetRestSeconds;
                                    }
                                    await _upsertSetRow(
                                      setIndex: setIndex,
                                      completed: !done,
                                      performedTimeSeconds: wasActive
                                          ? _activeSetElapsedSeconds
                                          : null,
                                      restAfterSeconds: wasActive
                                          ? _activeSetRestSeconds
                                          : null,
                                    );
                                    if (!mounted) return;
                                    if (!done) {
                                      final nextSet = _nextPendingSetIndex();
                                      setState(() {
                                        _activeSetIndex = nextSet ?? setIndex;
                                        _activeSetElapsedSeconds = 0;
                                        _activeSetRestSeconds = _restPresetSeconds;
                                      });
                                    } else {
                                      _stopRestCountdown();
                                    }
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? Colors.greenAccent.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: done
                                            ? Colors.greenAccent
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: done
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: rows.length > 1
                                      ? () => _deleteSetRow(setIndex)
                                      : null,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addSetRow,
              icon: const Icon(Icons.add),
              label: const Text("Add Set"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.16)),
                backgroundColor: Colors.white.withOpacity(0.05),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishExercise() async {
    if (submitting) return;

    setState(() => submitting = true);
    final t = AppLocalizations.of(context);
    try {
      _pauseActiveSetTimer();
      await _persistActiveSetTiming();
      _syncElapsedFromStart();
      _stopRestCountdown();
      timer?.cancel();
      _stopCardioStepsTracking();
      await TrainingActivityService.stopSession();
      await TrainingProgressStorage.saveLastExerciseFinishedMs(
        DateTime.now().millisecondsSinceEpoch,
      );
      final peId = _programExerciseId();
      if (peId != null) {
        await TrainingProgressStorage.clearExerciseTimerState(peId);
      }

      final rawProgramExerciseId = widget.exercise['program_exercise_id'];
      final int? programExerciseId = rawProgramExerciseId is int
          ? rawProgramExerciseId
          : int.tryParse(rawProgramExerciseId?.toString() ?? '');
      bool needsSync = false;
      final now = DateTime.now(); // device local

      final useSetRows = _supportsSetRows;
      final completedRows = _setRows
          .where((row) => _toBool(row['completed']))
          .toList(growable: false);
      final sourceRows = completedRows.isNotEmpty ? completedRows : _setRows;
      final int finalSets = useSetRows
          ? sourceRows.length
          : (int.tryParse(setsCtrl.text) ?? (widget.exercise['sets'] ?? 0));
      final int finalReps = useSetRows
          ? (_toInt(
              sourceRows.isNotEmpty
                  ? sourceRows.last['reps']
                  : widget.exercise['reps'],
            ))
          : (int.tryParse(repsCtrl.text) ?? (widget.exercise['reps'] ?? 0));
      final int finalRir = useSetRows
          ? (_toInt(
              sourceRows.isNotEmpty
                  ? sourceRows.last['rir']
                  : widget.exercise['rir'],
              fallback: rir.round(),
            ))
          : rir.round();

      final double? weight = useSetRows
          ? _toDouble(
              sourceRows.isNotEmpty
                  ? sourceRows.last['weight_kg']
                  : _plannedWeight(),
            )
          : double.tryParse(weightCtrl.text);
      final bool isCardio = _isCardioExercise();

      // Try to sync with server, but queue if offline
      if (programExerciseId != null) {
        try {
          // Start exercise if not already started
          if (!startRecorded) {
            try {
              await TrainingService.startExercise(
                programExerciseId,
                entryDate: now,
              );
              startRecorded = true;
            } catch (e) {
              // Queue start action
              await ExerciseActionQueue.queueAction(
                action: ExerciseActionQueue.actionStart,
                programExerciseId: programExerciseId,
                data: {
                  "entry_date":
                      "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
                },
              );
              needsSync = true;
            }
          }

          // Save weight if provided
          if (weight != null && weight > 0) {
            try {
              await TrainingService.saveWeight(programExerciseId, weight);
            } catch (e) {
              // Queue weight action
              await ExerciseActionQueue.queueAction(
                action: ExerciseActionQueue.actionWeight,
                programExerciseId: programExerciseId,
                data: {"weight": weight},
              );
              needsSync = true;
            }
          }

          // Finish exercise
          try {
            await TrainingService.finishExercise(
              programExerciseId: programExerciseId,
              sets: finalSets > 0 ? finalSets : null,
              reps: finalReps > 0 ? finalReps : null,
              rir: finalRir >= 0 ? finalRir : null,
              durationSeconds: seconds,
              entryDate: now,
            );
          } catch (e) {
            // Queue finish action
            await ExerciseActionQueue.queueAction(
              action: ExerciseActionQueue.actionFinish,
              programExerciseId: programExerciseId,
              data: {
                "sets": finalSets,
                "reps": finalReps,
                "rir": finalRir,
                "duration_seconds": seconds,
                "entry_date":
                    "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
              },
            );
            needsSync = true;
          }
        } catch (e) {
          // If all fails, queue everything
          needsSync = true;
        }
      }

      // Save cardio session metrics (distance/speed/time)
      if (isCardio) {
        final distanceKmValue = _cardioDistanceMeters / 1000.0;
        final shouldPersistCardio = distanceKmValue >= 0.1;
        final rawExerciseId = widget.exercise['exercise_id'];
        final int? exerciseId = rawExerciseId is int
            ? rawExerciseId
            : int.tryParse(rawExerciseId?.toString() ?? '');
        if (shouldPersistCardio) {
          final payload = {
            "program_exercise_id": programExerciseId,
            "exercise_id": exerciseId,
            "distance_km": distanceKmValue,
            "avg_pace_min_km": _paceMinPerKmFromDistance(
              distanceKmValue,
              seconds,
            ),
            "duration_seconds": seconds,
            "steps": _cardioSteps ?? 0,
            "route_points": _cardioRoute
                .map(
                  (p) => {
                    "lat": p.lat,
                    "lng": p.lng,
                    if (p.paused) "paused": true,
                  },
                )
                .toList(),
            "entry_date":
                "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          };
          try {
            await TrainingService.saveCardioSession(
              programExerciseId: programExerciseId,
              exerciseId: exerciseId,
              distanceKm: distanceKmValue,
              avgPaceMinKm: _paceMinPerKmFromDistance(distanceKmValue, seconds),
              durationSeconds: seconds,
              steps: _cardioSteps ?? 0,
              routePoints: _cardioRoute
                  .map(
                    (p) => {
                      "lat": p.lat,
                      "lng": p.lng,
                      if (p.paused) "paused": true,
                    },
                  )
                  .toList(),
              entryDate: now,
            );
          } catch (_) {
            await CardioSessionQueue.queueSession(payload);
            needsSync = true;
          }
        }
      }

      // Show message if queued for sync
      if (needsSync && mounted) {
        AppToast.show(
          context,
          t.translate("exercise_saved_offline") ??
              "Exercise saved offline. Will sync when online.",
          type: AppToastType.info,
        );
      }

      // For cardio: close this sheet, then show achievement sheet from root.
      if (isCardio && mounted) {
        final name = await AccountStorage.getName();
        final rootNav = Navigator.of(context, rootNavigator: true);
        final rootContext = rootNav.context;
        Navigator.of(context).maybePop(); // close ExerciseSessionSheet
        await Future.delayed(const Duration(milliseconds: 50));
        await showModalBottomSheet(
          context: rootContext,
          isDismissible: true,
          enableDrag: true,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CardioAchievementSheet(
            durationSeconds: seconds,
            distanceKm: _cardioDistanceMeters / 1000.0,
            avgSpeedKmh: _cardioSpeedKmh,
            steps: _cardioSteps ?? 0,
            route: _cardioRoute,
            userName: name,
          ),
        );
        AccountStorage.notifyTrainingChanged();
        return;
      }

      // Record that user completed an exercise today (diet page can auto-set "training day" and lock "rest day")
      await TrainingCompletionStorage.recordExerciseCompletedToday();
      await TrainingProgressStorage.recordTrainingDayCompleted(now);
      AccountStorage.notifyTrainingChanged();

      // Show feedback sheet (works offline)
      if (mounted) {
        if (programExerciseId == null) {
          widget.onFinished();
          Navigator.pop(context); // close ExerciseSessionSheet
          return;
        }
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => ExerciseFeedbackSheet(
            programExerciseId: programExerciseId,
            exerciseName: widget.exercise['exercise_name'],
            onDone: () {
              _feedbackHandled = true;
              widget.onFinished();
              Navigator.pop(context); // close ExerciseSessionSheet
            },
          ),
        ).whenComplete(() {
          if (!mounted) return;
          if (_feedbackHandled) return;
          _feedbackHandled = true;
          widget.onFinished();
          Navigator.pop(context); // close ExerciseSessionSheet
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          "Could not finish exercise. Please try again.",
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted && submitting) {
        setState(() => submitting = false);
      }
    }
  }

  void _cancelSession() {
    timer?.cancel();
    TrainingActivityService.stopSession();
    Navigator.of(context).maybePop();
  }

  void _pauseExercise() {
    _pauseExerciseCore();
  }

  Future<void> _pauseExerciseCore() async {
    if (!started) return;
    _pauseActiveSetTimer();
    await _persistActiveSetTiming();
    _syncElapsedFromStart();
    timer?.cancel();
    _cardioPausedAtSteps = _cardioRawSteps;
    _adjustStepsOnResume = true;
    _stopCardioStepsTracking();
    setState(() => _paused = true);
    _sessionStartMs = null;
    await TrainingActivityService.pauseSession(
      exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
      sets: _currentSets(),
      reps: _currentReps(),
      seconds: seconds,
      distanceKm: _isCardioExercise() ? (_cardioDistanceMeters / 1000.0) : null,
      paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
    );
  }

  Future<void> _pauseAndClose() async {
    await _pauseExerciseCore();
    AccountStorage.notifyTrainingChanged();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Keep tracking alive for active cardio sessions (background updates).
      if (!(started && !_paused && _isCardioExercise())) {
        timer?.cancel();
        _stopCardioStepsTracking();
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _syncElapsedFromStart(force: true);
      if (started && !_paused) {
        _startTimer();
        if (_isCardioExercise()) {
          _startCardioStepsTracking();
        }
        TrainingActivityService.updateSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: _currentSets(),
          reps: _currentReps(),
          seconds: seconds,
          distanceKm: _isCardioExercise()
              ? (_cardioDistanceMeters / 1000.0)
              : null,
          paceMinKm: _isCardioExercise() ? _currentPaceMinPerKm() : null,
        );
      }
    }
  }

  @override
  void dispose() {
    _saveTimerState();
    timer?.cancel();
    _activeSetTimer?.cancel();
    _restCountdownTimer?.cancel();
    _stepSub?.cancel();
    if (!_paused) {
      TrainingActivityService.stopSession();
    }
    weightCtrl.dispose();
    setsCtrl.dispose();
    repsCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int _currentSets() {
    final raw = int.tryParse(setsCtrl.text);
    if (raw != null && raw > 0) return raw;
    final ex = widget.exercise['sets'];
    if (ex is int) return ex;
    if (ex is String) return int.tryParse(ex) ?? 0;
    if (ex is num) return ex.toInt();
    return 0;
  }

  int _currentReps() {
    final raw = int.tryParse(repsCtrl.text);
    if (raw != null && raw > 0) return raw;
    final ex = widget.exercise['reps'];
    if (ex is int) return ex;
    if (ex is String) return int.tryParse(ex) ?? 0;
    if (ex is num) return ex.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isCardio = _isCardioExercise();
    final useSetRows = !isCardio && _supportsSetRows;
    final showSession = !isCardio && (started || widget.showSessionOnOpen);
    final token = dotenv.isInitialized
        ? dotenv.maybeGet('MAPBOX_PUBLIC_KEY')
        : null;
    final hasToken = token != null && token.trim().isNotEmpty;

    final animationUrl = (widget.exercise['animation_url'] ?? '')
        .toString()
        .trim();
    final String instructions = widget.exercise['instructions'] ?? '';
    final viewInsets = MediaQuery.of(context).viewInsets;
    final t = AppLocalizations.of(context);
    final compliance =
        _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);
    final String? overrideSets = _valueAsText(
      compliance?['performed_sets'] ?? widget.exercise['performed_sets'],
    );
    final String? overrideReps = _valueAsText(
      compliance?['performed_reps'] ?? widget.exercise['performed_reps'],
    );
    final String setsLabel = overrideSets ?? widget.exercise['sets'].toString();
    final String repsLabel = overrideReps ?? widget.exercise['reps'].toString();
    final String? overrideRir = _valueAsText(
      compliance?['performed_rir'] ?? widget.exercise['performed_rir'],
    );
    final String rirLabel = overrideRir ?? widget.exercise['rir'].toString();
    final contentPadding = isCardio
        ? EdgeInsets.fromLTRB(0, 0, 0, 18 + viewInsets.bottom)
        : EdgeInsets.fromLTRB(18, 18, 18, 18 + viewInsets.bottom);

    Widget animationWidget = const Icon(
      Icons.fitness_center,
      size: 80,
      color: Colors.grey,
    );

    if (!isCardio && animationUrl.isNotEmpty) {
      final String gifUrl = TrainingService.animationImageUrl(
        animationUrl,
        null,
      );

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final cacheH = (160 * dpr).round();

      animationWidget = SizedBox(
        height: 160,
        child: gifUrl.isEmpty
            ? const Icon(Icons.fitness_center, size: 80, color: Colors.grey)
            : Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.previewProvider != null)
                    Image(
                      image: widget.previewProvider!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  Image(
                    image: TrainingService.gifProvider(
                      gifUrl,
                      cacheHeight: cacheH,
                    ),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.fitness_center,
                        size: 80,
                        color: Colors.grey,
                      );
                    },
                  ),
                ],
              ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: submitting,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1325), Color(0xFF0B0F1A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: isCardio
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isCardio) ...[
                        SizedBox(
                          width: double.infinity,
                          child: CardioMap(
                            hasToken: hasToken,
                            expanded: _cardioMapExpanded,
                            height: MediaQuery.of(context).size.height * 0.9,
                            steps: _cardioSteps,
                            elapsedSeconds: seconds,
                            running: started && !_paused,
                            countdownActive: _countdownSessionStarted,
                            trackingEnabled:
                                started || _countdownSessionStarted,
                            onCountdownStart: () {
                              if (!started) {
                                setState(() => _countdownSessionStarted = true);
                                TrainingActivityService.startSession(
                                  exerciseName:
                                      (widget.exercise['exercise_name'] ?? '')
                                          .toString(),
                                  sets: _currentSets(),
                                  reps: _currentReps(),
                                  seconds: seconds,
                                  distanceKm: _cardioDistanceMeters / 1000.0,
                                  paceMinKm: _currentPaceMinPerKm(),
                                  paused: true,
                                  pausedSeconds: seconds,
                                );
                              } else if (!_paused) {
                                TrainingActivityService.updateSession(
                                  exerciseName:
                                      (widget.exercise['exercise_name'] ?? '')
                                          .toString(),
                                  sets: _currentSets(),
                                  reps: _currentReps(),
                                  seconds: seconds,
                                  distanceKm: _cardioDistanceMeters / 1000.0,
                                  paceMinKm: _currentPaceMinPerKm(),
                                );
                              }
                            },
                            onClose: _pauseAndClose,
                            onMetrics: (m) {
                              _cardioDistanceMeters = m.distanceMeters;
                              _cardioSpeedKmh = m.speedKmh;
                              if (started && !_paused) {
                                TrainingActivityService.updateSession(
                                  exerciseName:
                                      (widget.exercise['exercise_name'] ?? '')
                                          .toString(),
                                  sets: _currentSets(),
                                  reps: _currentReps(),
                                  seconds: seconds,
                                  distanceKm: _cardioDistanceMeters / 1000.0,
                                  paceMinKm: _currentPaceMinPerKm(),
                                );
                              }
                            },
                            onRoute: (route) {
                              _mergeIncomingCardioRoute(route);
                            },
                            onStart: _startExercise,
                            onPause: _pauseExercise,
                            onFinish: _finishExercise,
                          ),
                        ),
                        // const SizedBox(height: 12),
                        // Text(
                        //   widget.exercise['exercise_name'] ?? '',
                        //   textAlign: TextAlign.center,
                        //   style: const TextStyle(
                        //     fontSize: 19,
                        //     fontWeight: FontWeight.w800,
                        //     color: Colors.white,
                        //   ),
                        // ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF162447), Color(0xFF0D1325)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: animationWidget,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.exercise['exercise_name'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _SessionChip(
                                    icon: Icons.repeat,
                                    label: "$setsLabel x $repsLabel",
                                  ),
                                  _SessionChip(
                                    icon: Icons.bolt,
                                    label:
                                        "${t.translate("training_rir_label")} $rirLabel",
                                  ),
                                  if (started)
                                    _SessionChip(
                                      icon: Icons.timer,
                                      label: _time,
                                      accent: Colors.blueAccent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (!started && !isCardio && !widget.showSessionOnOpen)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade400,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            t.translate("training_start_exercise"),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onPressed: _onPrimaryExerciseButtonPressed,
                        ),
                      if (showSession) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.translate("training_session_title"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SessionChip(
                                    icon: Icons.timer,
                                    label: _time,
                                    accent: Colors.blueAccent,
                                  ),
                                  if (!isCardio)
                                    _SessionChip(
                                      icon: Icons.monitor_weight,
                                      label: t.translate(
                                        "training_log_weight_reps",
                                      ),
                                      accent: Colors.purpleAccent,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (useSetRows) ...[
                                _buildSetRowsEditor(),
                              ] else ...[
                                TextField(
                                  controller: weightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _inputStyle(
                                    t.translate("training_weight_label"),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: setsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputStyle(
                                    t.translate("training_performed_sets"),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: repsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputStyle(
                                    t.translate("training_performed_reps"),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      t.translate("training_rir_label"),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      rir.round().toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  min: 0,
                                  max: 3,
                                  divisions: 3,
                                  value: rir,
                                  activeColor: Colors.greenAccent,
                                  inactiveColor: Colors.white24,
                                  onChanged: (v) => setState(() => rir = v),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: submitting
                                          ? null
                                          : _cancelSession,
                                      child: Text(t.translate("common_cancel")),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.greenAccent.shade400,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: submitting
                                          ? null
                                          : _onPrimaryExerciseButtonPressed,
                                      child: (submitting && started)
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : Text(
                                              started
                                                  ? t.translate("finish")
                                                  : t.translate(
                                                      "training_start_exercise",
                                                    ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              if (instructions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.white.withOpacity(
                                      0.04,
                                    ),
                                  ),
                                  icon: const Icon(Icons.menu_book),
                                  label: Text(
                                    t.translate("training_instructions_title"),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: _openInstructionDialog,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (submitting)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _inputStyle(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.greenAccent),
    ),
  );
}

class _SessionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _SessionChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (accent ?? Colors.white).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ?? Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RestPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.orangeAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? Colors.orangeAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.orangeAccent : Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CompactButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
