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

  const ExerciseSessionSheet({
    super.key,
    required this.exercise,
    required this.completedExerciseNames,
    required this.onFinished,
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

  int seconds = 0;
  Timer? timer;
  int? _sessionStartMs;

  final weightCtrl = TextEditingController();
  final setsCtrl = TextEditingController();
  final repsCtrl = TextEditingController();

  double rir = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefillFromLastEntry();
    _restoreActiveSession();
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

  Future<void> _restoreActiveSession() async {
    final session = await TrainingActivityService.getActiveSession();
    if (!mounted || session == null) return;
    final currentName =
        (widget.exercise['exercise_name'] ?? '').toString().trim().toLowerCase();
    final sessionName =
        (session['name'] ?? '').toString().trim().toLowerCase();
    if (currentName.isEmpty || sessionName != currentName) return;
    final paused = session['paused'] == true;
    final pausedSeconds = session['pausedSeconds'] as int?;
    _sessionStartMs = paused ? null : session['startMs'] as int?;
    _syncElapsedFromStart();
    if (!started) {
      setState(() {
        started = true;
        _paused = paused;
        if (paused && pausedSeconds != null) {
          seconds = pausedSeconds;
        }
      });
      if (!paused) {
        _startTimer();
        if (_isCardioExercise()) {
          await _startCardioStepsTracking();
        }
      }
    }
  }

  void _syncElapsedFromStart() {
    if (_paused) return;
    final startMs = _sessionStartMs;
    if (startMs == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = ((nowMs - startMs) / 1000).round();
    if (elapsed != seconds) {
      setState(() => seconds = elapsed);
    }
  }

  void _prefillFromLastEntry() {
    final compliance = _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);

    final performedSets = compliance?['performed_sets'] ?? widget.exercise['performed_sets'];
    final performedReps = compliance?['performed_reps'] ?? widget.exercise['performed_reps'];
    final weightUsed = compliance?['weight_used'] ?? widget.exercise['weight_used'];
    final performedRir = compliance?['performed_rir'] ?? widget.exercise['performed_rir'];

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
    final rawName = (widget.exercise['exercise_name'] ?? '').toString().trim().toLowerCase();
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
        final speedKmh = isCardio ? _cardioSpeedKmh : null;
        final pace = distanceKm != null
            ? _paceMinPerKmFromDistance(distanceKm, seconds)
            : (speedKmh != null ? _paceMinPerKm(speedKmh) : null);
        TrainingActivityService.updateSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: sets,
          reps: reps,
          seconds: seconds,
          distanceKm: distanceKm,
          speedKmh: pace,
        );
      }
    });
  }

  Future<void> _startCardioStepsTracking() async {
    if (!_isCardioExercise()) return;
    _cardioSteps ??= 0;
    if (mounted) setState(() {});
    _stepSub?.cancel();
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
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
      },
      onError: (_) {},
    );
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
          distanceKm: _isCardioExercise() ? (_cardioDistanceMeters / 1000.0) : null,
          speedKmh: _isCardioExercise()
              ? _paceMinPerKmFromDistance(_cardioDistanceMeters / 1000.0, seconds)
              : null,
        );
      }
      await _startCardioStepsTracking();
      await TrainingActivityService.startSession(
        exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
        sets: _currentSets(),
        reps: _currentReps(),
        seconds: seconds,
        distanceKm: _isCardioExercise() ? (_cardioDistanceMeters / 1000.0) : null,
        speedKmh: _isCardioExercise()
            ? _paceMinPerKmFromDistance(_cardioDistanceMeters / 1000.0, seconds)
            : null,
      );
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
    await TrainingActivityService.startSession(
      exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
      sets: _currentSets(),
      reps: _currentReps(),
      seconds: seconds,
      distanceKm: _isCardioExercise() ? (_cardioDistanceMeters / 1000.0) : null,
      speedKmh: _isCardioExercise()
          ? _paceMinPerKmFromDistance(_cardioDistanceMeters / 1000.0, seconds)
          : null,
    );
    
    // Queue start action for sync (non-blocking)
    final rawProgramExerciseId = widget.exercise['program_exercise_id'];
    final int? programExerciseId = rawProgramExerciseId is int
        ? rawProgramExerciseId
        : int.tryParse(rawProgramExerciseId?.toString() ?? '');
    if (programExerciseId != null) {
      try {
        // Try to start on server immediately
        await TrainingService.startExercise(programExerciseId);
        startRecorded = true;
      } catch (e) {
        // If offline, queue for later sync
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionStart,
          programExerciseId: programExerciseId,
        );
        startRecorded = false; // Will be recorded when syncing
      }
    }
  }

  Future<void> _finishExercise() async {
    if (submitting) return;

    setState(() => submitting = true);
    _syncElapsedFromStart();
    timer?.cancel();
    _stopCardioStepsTracking();
    await TrainingActivityService.stopSession();

    final t = AppLocalizations.of(context);
    final rawProgramExerciseId = widget.exercise['program_exercise_id'];
    final int? programExerciseId = rawProgramExerciseId is int
        ? rawProgramExerciseId
        : int.tryParse(rawProgramExerciseId?.toString() ?? '');
    bool needsSync = false;
    final now = DateTime.now(); // device local

    final int finalSets =
        int.tryParse(setsCtrl.text) ?? (widget.exercise['sets'] ?? 0);
    final int finalReps =
        int.tryParse(repsCtrl.text) ?? (widget.exercise['reps'] ?? 0);

    final double? weight = double.tryParse(weightCtrl.text);
    final bool isCardio = _isCardioExercise();

    // Try to sync with server, but queue if offline
    if (programExerciseId != null) try {
      // Start exercise if not already started
      if (!startRecorded) {
        try {
          await TrainingService.startExercise(programExerciseId, entryDate: now);
          startRecorded = true;
        } catch (e) {
          // Queue start action
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionStart,
            programExerciseId: programExerciseId,
            data: {"entry_date": "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}"},
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
          sets: finalSets,
          reps: finalReps,
          rir: rir.round(),
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
            "rir": rir.round(),
            "duration_seconds": seconds,
            "entry_date": "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          },
        );
        needsSync = true;
      }
    } catch (e) {
      // If all fails, queue everything
      needsSync = true;
    }

    // Save cardio session metrics (distance/speed/time)
    if (isCardio) {
      final rawExerciseId = widget.exercise['exercise_id'];
      final int? exerciseId = rawExerciseId is int
          ? rawExerciseId
          : int.tryParse(rawExerciseId?.toString() ?? '');
      final payload = {
        "program_exercise_id": programExerciseId,
        "exercise_id": exerciseId,
        "distance_km": _cardioDistanceMeters / 1000.0,
        "avg_pace_min_km":
            _paceMinPerKmFromDistance(_cardioDistanceMeters / 1000.0, seconds),
        "duration_seconds": seconds,
        "steps": _cardioSteps ?? 0,
        "route_points": _cardioRoute
            .map((p) => {"lat": p.lat, "lng": p.lng})
            .toList(),
        "entry_date": "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      };
      try {
        await TrainingService.saveCardioSession(
          programExerciseId: programExerciseId,
          exerciseId: exerciseId,
          distanceKm: _cardioDistanceMeters / 1000.0,
          avgPaceMinKm:
              _paceMinPerKmFromDistance(_cardioDistanceMeters / 1000.0, seconds),
          durationSeconds: seconds,
          steps: _cardioSteps ?? 0,
          routePoints: _cardioRoute
              .map((p) => {"lat": p.lat, "lng": p.lng})
              .toList(),
          entryDate: now,
        );
      } catch (_) {
        await CardioSessionQueue.queueSession(payload);
        needsSync = true;
      }
    }

    // Show message if queued for sync
    if (needsSync && mounted) {
      AppToast.show(
        context,
        t.translate("exercise_saved_offline") ?? "Exercise saved offline. Will sync when online.",
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
      return;
    }

    // Record that user completed an exercise today (diet page can auto-set "training day" and lock "rest day")
    await TrainingCompletionStorage.recordExerciseCompletedToday();
    AccountStorage.notifyTrainingChanged();

    // Show feedback sheet (works offline)
    if (mounted) {
      if (submitting) {
        setState(() => submitting = false);
      }
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
      speedKmh: _isCardioExercise() ? _cardioSpeedKmh : null,
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
      _syncElapsedFromStart();
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
          distanceKm: _isCardioExercise() ? (_cardioDistanceMeters / 1000.0) : null,
          speedKmh: _isCardioExercise() ? _cardioSpeedKmh : null,
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
    final token =
        dotenv.isInitialized ? dotenv.maybeGet('MAPBOX_PUBLIC_KEY') : null;
    final hasToken = token != null && token.trim().isNotEmpty;

    final animationUrl = (widget.exercise['animation_url'] ?? '').toString().trim();
    final animPath = (widget.exercise['animation_rel_path'] ?? '').toString().trim();
    final String instructions = widget.exercise['instructions'] ?? '';
    final viewInsets = MediaQuery.of(context).viewInsets;
    final t = AppLocalizations.of(context);
    final compliance = _extractCompliance(widget.exercise['program_compliance']) ??
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

    if (!isCardio && (animationUrl.isNotEmpty || animPath.isNotEmpty)) {
      final String gifUrl =
          TrainingService.animationImageUrl(animationUrl, animPath);

      animationWidget = SizedBox(
        height: 160,
        child: Image.network(
          gifUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.fitness_center,
              size: 80,
              color: Colors.grey,
            );
          },
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
                  physics: isCardio ? const NeverScrollableScrollPhysics() : null,
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
                      trackingEnabled: started,
                      onClose: _pauseAndClose,
                      onMetrics: (m) {
                        _cardioDistanceMeters = m.distanceMeters;
                        _cardioSpeedKmh = m.speedKmh;
                        if (started && !_paused) {
                          TrainingActivityService.updateSession(
                            exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
                            sets: _currentSets(),
                            reps: _currentReps(),
                            seconds: seconds,
                            distanceKm: _cardioDistanceMeters / 1000.0,
                            speedKmh: _cardioSpeedKmh,
                          );
                        }
                      },
                      onRoute: (route) {
                        _cardioRoute = route;
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
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                              label: "${t.translate("training_rir_label")} $rirLabel",
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
                if (!started && !isCardio)
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
                    onPressed: _startExercise,
                  ),
                if (started && !isCardio) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                label: t.translate("training_log_weight_reps"),
                                accent: Colors.purpleAccent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              _inputStyle(t.translate("training_weight_label")),
                        ),
                        if (!isCardio) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: setsCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                _inputStyle(t.translate("training_performed_sets")),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: repsCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                _inputStyle(t.translate("training_performed_reps")),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t.translate("training_rir_label"),
                                style: const TextStyle(color: Colors.white70),
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
                                onPressed: submitting ? null : _cancelSession,
                                child: Text(t.translate("common_cancel")),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade400,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: submitting ? null : _finishExercise,
                                child: submitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        t.translate("finish"),
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
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.04),
                            ),
                            icon: const Icon(Icons.menu_book),
                            label: Text(
                              t.translate("training_instructions_title"),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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

  const _SessionChip({
    required this.icon,
    required this.label,
    this.accent,
  });

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
