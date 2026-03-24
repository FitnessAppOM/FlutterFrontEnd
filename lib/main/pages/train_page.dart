import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/training/day_selector.dart';
import '../../widgets/training/exercise_card.dart';
import '../../widgets/training/exercise_session_sheet.dart';
import '../../core/account_storage.dart';
import '../../core/training_regeneration_flag.dart';
import '../../localization/app_localizations.dart';
import '../../services/auth/profile_service.dart';
import '../../services/training/training_service.dart';
import '../../widgets/training/replace_exercise_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../screens/cardio/cardio_tab.dart';
import '../../consents/consent_manager.dart';
import '../../screens/training/training_history_page.dart';
import '../../widgets/training/training_day_complete_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/training/training_progress_storage.dart';
import '../../services/training/training_activity_service.dart';
import '../../services/health/workout_health_sync_service.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _DayOrderResult {
  const _DayOrderResult({required this.order, required this.completedByIndex});

  final List<int> order;
  final List<bool> completedByIndex;
}

class _TrainPageState extends State<TrainPage> {
  Map<String, dynamic>? program;
  int selectedDay = 0;
  bool loading = true;
  bool isOffline = false;
  Set<String> completedExerciseNames = {};
  int _tabIndex = 0; // 0 = Train, 1 = Cardio
  bool _cardioBuilt = false;
  List<Map<String, dynamic>> _trainExercises = const [];
  List<Map<String, dynamic>> _cardioExercises = const [];
  final Set<String> _preloadedThumbs = <String>{};
  List<int> _dayOrder = const [];
  List<bool> _dayCompletedByIndex = const [];
  bool _cardioLockToday = false;
  bool _isDeactivated = false;
  final Set<int> _inProgressExerciseIds = <int>{};
  String? _activeSessionExerciseName;
  int _inProgressLoadSeq = 0;
  Set<String> _finishedDayKeysForWeek = <String>{};

  int? _userId;
  int? _pendingCompletionDayIndex;

  int? _workoutStartMs;
  int? _workoutDayIndex;
  int _workoutElapsedSeconds = 0;
  Timer? _workoutTimer;
  bool _finishingWorkout = false;

  int _exRestPresetSeconds = 60;
  int _exRestRemaining = 0;
  bool _exRestActive = false;
  bool _showExRestPanel = false;
  Timer? _exRestTimer;

  @override
  void initState() {
    super.initState();
    AccountStorage.trainingChange.addListener(_onTrainingChanged);
    AccountStorage.accountChange.addListener(_onAccountChanged);
    _init();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _exRestTimer?.cancel();
    AccountStorage.trainingChange.removeListener(_onTrainingChanged);
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    super.dispose();
  }

  void _onTrainingChanged() {
    _loadWorkoutTimer();
    _loadCardioLock();
  }

  void _onAccountChanged() {
    _refreshAccountStatus();
  }

  Future<void> _init() async {
    _userId = await AccountStorage.getUserId();
    await _loadProgram();
    await _loadWorkoutTimer();
    await _loadCardioLock();
    await _refreshAccountStatus();
    await _loadExRestPreset();
    await _restoreExRestState();
  }

  Future<void> _refreshAccountStatus() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) return;
    try {
      final data = await ProfileApi.fetchAccountStatus(userId);
      final status = (data["status"] ?? "").toString().toLowerCase().trim();
      if (!mounted) return;
      setState(() => _isDeactivated = status == "deactivated");
    } catch (_) {}
  }

  Future<void> _loadWorkoutTimer() async {
    final startMs = await TrainingProgressStorage.getWorkoutStartMs();
    final lastExerciseFinishedMs =
        await TrainingProgressStorage.getLastExerciseFinishedMs();
    final hasFinishedExerciseInSession =
        startMs != null &&
        lastExerciseFinishedMs != null &&
        lastExerciseFinishedMs >= startMs;
    final storedWorkoutDayIndex =
        await TrainingProgressStorage.getWorkoutDayIndex();
    final activeSession = await TrainingActivityService.getActiveSession();
    final normalizedSessionName = _normalizeExerciseName(
      activeSession?['name'],
    );
    int? resolvedWorkoutDayIndex = storedWorkoutDayIndex;
    if (startMs != null && resolvedWorkoutDayIndex == null) {
      resolvedWorkoutDayIndex = await _inferActiveWorkoutDayIndexFromProgram();
    }
    if (startMs != null) {
      resolvedWorkoutDayIndex ??= selectedDay;
    }
    if (!mounted) return;
    if (startMs != null) {
      _workoutStartMs = startMs;
      _workoutDayIndex = resolvedWorkoutDayIndex;
      _syncWorkoutElapsed();
      _startWorkoutTicker();
    } else {
      _workoutStartMs = null;
      _workoutDayIndex = null;
      _workoutElapsedSeconds = 0;
      _workoutTimer?.cancel();
      _workoutTimer = null;
    }
    _activeSessionExerciseName = normalizedSessionName.isEmpty
        ? null
        : normalizedSessionName;
    if (mounted) {
      setState(() {
        _showExRestPanel = hasFinishedExerciseInSession || _exRestActive;
      });
    }
    await _refreshInProgressExercises();
  }

  void _syncWorkoutElapsed() {
    final ms = _workoutStartMs;
    if (ms == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _workoutElapsedSeconds = ((now - ms) / 1000).round();
  }

  void _startWorkoutTicker() {
    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _syncWorkoutElapsed();
      setState(() {});
    });
  }

  String _formatWorkoutTime(int total) {
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _finishWorkout({bool showToast = true}) async {
    if (_finishingWorkout) return;
    final finishedDayIndex = selectedDay;
    final sessionStartMs =
        _workoutStartMs ?? await TrainingProgressStorage.getWorkoutStartMs();
    final lastExerciseFinishedMs =
        await TrainingProgressStorage.getLastExerciseFinishedMs();
    final hasCompletedExerciseInSession =
        sessionStartMs != null &&
        lastExerciseFinishedMs != null &&
        lastExerciseFinishedMs >= sessionStartMs;
    setState(() => _finishingWorkout = true);
    final now = DateTime.now();
    // If an exercise is in progress, force-stop and clear its local progress.
    try {
      await TrainingActivityService.stopSession();
    } catch (_) {
      // Ignore local stop errors and continue finishing workout.
    }
    await TrainingProgressStorage.clearAllExerciseTimers();
    _activeSessionExerciseName = null;
    _inProgressExerciseIds.clear();
    if (hasCompletedExerciseInSession) {
      try {
        await TrainingService.finishSession(entryDate: now);
      } catch (_) {
        final hasActiveSession = await TrainingService.hasActiveSession();
        if (hasActiveSession) {
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionSessionFinish,
            programExerciseId: 0,
            data: {
              "entry_date":
                  "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
            },
          );
        }
      }
      try {
        String? workoutBrandName;
        int? workoutDayId;
        String? workoutDayKey;
        final programDays = program?['days'];
        if (programDays is List &&
            finishedDayIndex >= 0 &&
            finishedDayIndex < programDays.length) {
          final day = programDays[finishedDayIndex];
          if (day is Map) {
            final rawLabel = (day['day_label'] ?? day['label'] ?? '')
                .toString()
                .trim();
            if (rawLabel.isNotEmpty) {
              workoutBrandName = rawLabel;
            }
            final rawDayId = day['day_id'] ?? day['training_day_id'];
            final parsedDayId = rawDayId is int
                ? rawDayId
                : (rawDayId is num
                      ? rawDayId.toInt()
                      : int.tryParse(rawDayId?.toString() ?? ''));
            if (parsedDayId != null && parsedDayId > 0) {
              workoutDayId = parsedDayId;
            }
            final rawDayKey = day['day_key']?.toString().trim();
            if (rawDayKey != null && rawDayKey.isNotEmpty) {
              workoutDayKey = rawDayKey;
            }
          }
        }
        final healthSyncService = WorkoutHealthSyncService();
        final trainingDayDedupeSignature = healthSyncService
            .buildTrainingHistoryDayDedupeSignature(
              day: now,
              trainingDayId: workoutDayId,
              dayKey: workoutDayKey,
              label: workoutBrandName,
            );
        await healthSyncService.writeWorkoutSession(
          start: DateTime.fromMillisecondsSinceEpoch(sessionStartMs),
          end: now,
          title: "TAQA Workout Session",
          isCardio: false,
          workoutBrandName: workoutBrandName,
          isIndoorWorkout: true,
          dedupeSignature: trainingDayDedupeSignature,
          verifyHealthIfCachedDedupeSignature: true,
          syncIdentifier: trainingDayDedupeSignature,
          syncVersion: now.millisecondsSinceEpoch,
        );
      } catch (_) {
        // Ignore health write failures and continue local finish flow.
      }
    }
    await _refreshProgramForCompletionCheck();
    final shouldShowDayCompletePopup = hasCompletedExerciseInSession
        ? _isDayFullyCompletedForCurrentWeek(finishedDayIndex)
        : false;
    await TrainingProgressStorage.clearWorkoutStart();
    if (hasCompletedExerciseInSession) {
      await TrainingProgressStorage.recordTrainingDayCompleted(now);
      await _markDayFinishedForCurrentWeek(finishedDayIndex);
    }
    _workoutTimer?.cancel();
    _workoutTimer = null;
    _workoutStartMs = null;
    _workoutDayIndex = null;
    _workoutElapsedSeconds = 0;
    _stopExRestCountdownQuiet();
    final days = program?['days'];
    _DayOrderResult? orderResult = days is List ? _buildDayOrder(days) : null;
    if (hasCompletedExerciseInSession &&
        days is List &&
        finishedDayIndex >= 0 &&
        finishedDayIndex < days.length &&
        (orderResult == null ||
            finishedDayIndex >= orderResult.completedByIndex.length ||
            !orderResult.completedByIndex[finishedDayIndex])) {
      final forcedCompleted = List<bool>.filled(days.length, false);
      final source = orderResult?.completedByIndex;
      if (source != null) {
        for (var i = 0; i < forcedCompleted.length && i < source.length; i++) {
          forcedCompleted[i] = source[i];
        }
      } else if (_dayCompletedByIndex.length == days.length) {
        for (var i = 0; i < forcedCompleted.length; i++) {
          forcedCompleted[i] = _dayCompletedByIndex[i];
        }
      }
      forcedCompleted[finishedDayIndex] = true;
      orderResult = _DayOrderResult(
        order: _orderByCompletionFlags(forcedCompleted),
        completedByIndex: forcedCompleted,
      );
    }
    _pendingCompletionDayIndex =
        hasCompletedExerciseInSession && shouldShowDayCompletePopup
        ? finishedDayIndex
        : null;
    if (mounted) {
      setState(() {
        _finishingWorkout = false;
        _showExRestPanel = false;
        if (orderResult != null) {
          _dayOrder = orderResult.order;
          _dayCompletedByIndex = orderResult.completedByIndex;
          if (days is List) {
            selectedDay = _firstDayInOrder(orderResult, days.length);
          }
          _rebuildExerciseLists();
        }
      });
      if (showToast) {
        AppToast.show(
          context,
          hasCompletedExerciseInSession
              ? "Workout finished!"
              : "No exercises done. Session discarded.",
          type: hasCompletedExerciseInSession
              ? AppToastType.success
              : AppToastType.info,
        );
      }
      await _maybeShowDayCompletedPopup();
    }
  }

  Future<void> _loadExRestPreset() async {
    final preset = await TrainingProgressStorage.getExerciseRestPreset();
    if (mounted) setState(() => _exRestPresetSeconds = preset);
  }

  void _setExRestPreset(int s) {
    setState(() {
      _exRestPresetSeconds = s;
      if (!_exRestActive) _exRestRemaining = s;
    });
    TrainingProgressStorage.saveExerciseRestPreset(s);
  }

  Future<void> _setCustomExRestPreset() async {
    final ctrl = TextEditingController(
      text: _exRestPresetSeconds > 0 ? _exRestPresetSeconds.toString() : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121727),
        title: const Text(
          "Custom rest (seconds)",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Seconds",
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orangeAccent),
            ),
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
      ),
    );
    if (saved != true) return;
    final next = int.tryParse(ctrl.text.trim()) ?? 0;
    if (next > 0) _setExRestPreset(next);
  }

  String _formatRestTime(int total) {
    final safe = total < 0 ? 0 : total;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _startExRestCountdown([int? restSeconds]) {
    _stopExRestCountdownQuiet();
    final total = restSeconds ?? _exRestPresetSeconds;
    if (total <= 0) return;
    _exRestRemaining = total;
    _exRestActive = true;
    TrainingProgressStorage.saveExerciseRestCountdown(
      totalSeconds: total,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _exRestTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopExRestCountdownQuiet();
        return;
      }
      setState(() {
        _exRestRemaining--;
        if (_exRestRemaining <= 0) {
          _stopExRestCountdownQuiet();
        }
      });
    });
    if (mounted) setState(() {});
  }

  void _stopExRestCountdownQuiet() {
    _exRestTimer?.cancel();
    _exRestTimer = null;
    _exRestActive = false;
    _exRestRemaining = 0;
    TrainingProgressStorage.clearExerciseRestCountdown();
  }

  void _skipExRest() {
    _stopExRestCountdownQuiet();
    if (mounted) setState(() {});
  }

  Future<void> _restoreExRestState() async {
    final state = await TrainingProgressStorage.loadExerciseRestCountdown();
    if (state == null || !mounted) return;
    final total = state['totalSeconds'] as int? ?? 0;
    final startedAt = state['startedAtMs'] as int? ?? 0;
    if (total <= 0 || startedAt <= 0) return;
    final elapsed = ((DateTime.now().millisecondsSinceEpoch - startedAt) / 1000)
        .round();
    final remaining = total - elapsed;
    if (remaining > 0) {
      _startExRestCountdown(remaining);
    } else {
      await TrainingProgressStorage.clearExerciseRestCountdown();
    }
  }

  Future<void> _loadProgram() async {
    bool showedCache = false;
    try {
      final userId = _userId ?? await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");
      _userId = userId;
      await _loadFinishedDaysForCurrentWeek();

      // Show cached program immediately if available (no blank UI), except
      // right after a regeneration where cache may still be the old plan.
      if (program == null && !TrainingRegenerationFlag.isRegenerating) {
        try {
          final cached = await TrainingService.fetchActiveProgramFromCache();
          if (cached != null && mounted) {
            final cachedDays = cached['days'];
            final cachedDayCount = cachedDays is List ? cachedDays.length : 0;
            final orderResult = cachedDays is List
                ? _buildDayOrder(cachedDays)
                : const _DayOrderResult(order: [], completedByIndex: []);
            setState(() {
              program = cached;
              loading = false;
              isOffline = false;
              _dayOrder = orderResult.order;
              _dayCompletedByIndex = orderResult.completedByIndex;
              selectedDay = _firstDayInOrder(orderResult, cachedDayCount);
              _rebuildExerciseLists();
            });
            showedCache = true;
            _preloadExerciseGifsForCurrentDay();
            unawaited(_refreshInProgressExercises());
          }
        } catch (_) {
          // Ignore cache load errors.
        }
      }

      // Try to sync queued actions first (if online)
      try {
        await ExerciseActionQueue.syncQueue();
      } catch (_) {
        // Ignore sync errors, continue loading program
      }

      // Try to fetch from server first
      final data = await TrainingService.fetchActiveProgram(userId);
      Set<String> completed = {};
      try {
        final names = await TrainingService.fetchCompletedExerciseNames(userId);
        completed = names
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      } catch (_) {
        // Ignore completed names fetch errors
      }
      if (!mounted) return;
      final serverDays = data['days'];
      final serverDayCount = serverDays is List ? serverDays.length : 0;
      final orderResult = serverDays is List
          ? _buildDayOrder(serverDays)
          : const _DayOrderResult(order: [], completedByIndex: []);
      setState(() {
        program = data;
        loading = false;
        isOffline = false;
        completedExerciseNames = completed;
        _dayOrder = orderResult.order;
        _dayCompletedByIndex = orderResult.completedByIndex;
        selectedDay = _firstDayInOrder(orderResult, serverDayCount);
        _rebuildExerciseLists();
      });
      TrainingRegenerationFlag.clear();
      _preloadExerciseGifsForCurrentDay();
      await _refreshInProgressExercises();
      await _maybeShowDayCompletedPopup();
      return;
    } catch (_) {
      if (!mounted) return;
      if (program != null || showedCache) {
        setState(() {
          loading = false;
          isOffline = true;
        });
        if (showedCache) {
          final t = AppLocalizations.of(context);
          AppToast.show(
            context,
            t.translate("offline_mode_using_cached_data") ??
                "Offline: Using cached data",
            type: AppToastType.info,
          );
        }
      } else {
        setState(() {
          loading = false;
          program = null;
          isOffline = false;
          _dayOrder = const [];
          _dayCompletedByIndex = const [];
          _inProgressExerciseIds.clear();
          _activeSessionExerciseName = null;
          _rebuildExerciseLists();
        });
      }
    }
  }

  void _rebuildExerciseLists() {
    final data = program;
    if (data == null) {
      _trainExercises = const [];
      _cardioExercises = const [];
      return;
    }
    final days = data['days'];
    if (days is! List || days.isEmpty) {
      _trainExercises = const [];
      _cardioExercises = const [];
      return;
    }
    if (selectedDay >= days.length) {
      selectedDay = 0;
    }
    final currentDay = days[selectedDay];
    final exercises = currentDay is Map ? currentDay['exercises'] : null;
    final List<Map<String, dynamic>> train = [];
    final List<Map<String, dynamic>> cardio = [];
    if (exercises is List) {
      for (final ex in exercises) {
        if (ex is Map<String, dynamic>) {
          if (_isCardioExercise(ex)) {
            cardio.add(ex);
          } else {
            train.add(ex);
          }
        }
      }
    }
    _trainExercises = train;
    _cardioExercises = cardio;
  }

  String _normalizeExerciseName(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  int? _programExerciseId(Map<String, dynamic> ex) {
    final raw = ex['program_exercise_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<int?> _inferActiveWorkoutDayIndexFromProgram() async {
    final data = program;
    if (data == null) return null;
    final days = data['days'];
    if (days is! List) return null;
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final exercises = day is Map ? day['exercises'] : null;
      if (exercises is! List) continue;
      for (final ex in exercises) {
        if (ex is! Map) continue;
        final exMap = ex is Map<String, dynamic>
            ? ex
            : Map<String, dynamic>.from(ex);
        final id = _programExerciseId(exMap);
        if (id == null) continue;
        final state = await TrainingProgressStorage.loadExerciseTimerState(id);
        if (state?['started'] == true) {
          return dayIndex;
        }
      }
    }
    return null;
  }

  Future<void> _refreshInProgressExercises() async {
    final seq = ++_inProgressLoadSeq;
    final exercises = List<Map<String, dynamic>>.from(_trainExercises);
    if (exercises.isEmpty) {
      if (!mounted || seq != _inProgressLoadSeq) return;
      if (_inProgressExerciseIds.isNotEmpty) {
        setState(() => _inProgressExerciseIds.clear());
      }
      return;
    }

    final inProgressIds = <int>{};

    for (final ex in exercises) {
      final id = _programExerciseId(ex);
      if (id == null) continue;
      final state = await TrainingProgressStorage.loadExerciseTimerState(id);
      if (state == null) continue;
      if (state['started'] == true) {
        inProgressIds.add(id);
      }
    }

    if (!mounted || seq != _inProgressLoadSeq) return;
    final changed =
        inProgressIds.length != _inProgressExerciseIds.length ||
        !inProgressIds.containsAll(_inProgressExerciseIds);
    if (!changed) return;
    setState(() {
      _inProgressExerciseIds
        ..clear()
        ..addAll(inProgressIds);
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasLongCardioOnDate(List<Map<String, dynamic>> items, DateTime date) {
    for (final item in items) {
      final dt = _parseDateTime(item['entry_date']);
      if (dt == null || !_sameDay(dt, date)) continue;
      final raw = item['duration_seconds'];
      final secs = raw is int
          ? raw
          : (raw is num
                ? raw.toInt()
                : int.tryParse(raw?.toString() ?? '') ?? 0);
      if (secs >= 15 * 60) return true;
    }
    return false;
  }

  Future<void> _loadCardioLock() async {
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    bool locked = false;
    try {
      final items = await TrainingService.fetchCardioHistory(
        userId: userId,
        limit: 60,
      );
      locked = _hasLongCardioOnDate(items, DateTime.now());
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _cardioLockToday = locked);
  }

  _DayOrderResult _buildDayOrder(List days) {
    if (days.isEmpty) {
      return const _DayOrderResult(order: [], completedByIndex: []);
    }
    final now = DateTime.now();
    final weekStart = _weekStartMonday(now);
    final completedByIndex = List<bool>.filled(days.length, false);
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is Map<String, dynamic>) {
        completedByIndex[i] = _isDayFinishedForCurrentWeek(day, i, weekStart);
      } else if (day is Map) {
        completedByIndex[i] = _isDayFinishedForCurrentWeek(
          Map<String, dynamic>.from(day),
          i,
          weekStart,
        );
      }
    }
    final order = _orderByCompletionFlags(completedByIndex);
    return _DayOrderResult(order: order, completedByIndex: completedByIndex);
  }

  List<int> _orderByCompletionFlags(List<bool> completedByIndex) {
    final incomplete = <int>[];
    final complete = <int>[];
    for (var i = 0; i < completedByIndex.length; i++) {
      if (completedByIndex[i]) {
        complete.add(i);
      } else {
        incomplete.add(i);
      }
    }
    return <int>[...incomplete, ...complete];
  }

  List<int> _effectiveDayOrder(List days) {
    if (_dayOrder.length == days.length) return _dayOrder;
    return List<int>.generate(days.length, (i) => i);
  }

  int _firstDayInOrder(_DayOrderResult orderResult, int dayCount) {
    final hasWorkoutInProgress = _workoutStartMs != null;
    if (hasWorkoutInProgress && selectedDay >= 0 && selectedDay < dayCount) {
      return selectedDay;
    }
    if (orderResult.order.isNotEmpty) return orderResult.order.first;
    if (selectedDay >= 0 && selectedDay < dayCount) return selectedDay;
    return 0;
  }

  Future<void> _preloadExerciseGifsForCurrentDay() async {
    if (!mounted) return;
    try {
      final dpr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
      final thumbW = (74 * dpr).round();
      final thumbH = (66 * dpr).round();
      for (final ex in _trainExercises) {
        if (!mounted) return;
        final url = TrainingService.animationImageUrl(
          ex['animation_url']?.toString(),
          null,
        );
        if (url.isEmpty) continue;
        final key = "$url|$thumbW|$thumbH";
        if (_preloadedThumbs.contains(key)) continue;
        _preloadedThumbs.add(key);
        try {
          await TrainingService.warmGif(
            context,
            url,
            cacheWidth: thumbW,
            cacheHeight: thumbH,
          );
        } catch (_) {
          // Ignore individual preload failures.
        }
      }
    } catch (_) {
      // Ignore preload failures.
    }
  }

  Future<void> _startExerciseFlow(Map<String, dynamic> ex) async {
    _stopExRestCountdownQuiet();
    if (mounted) setState(() {});
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thumbW = (74 * dpr).round();
    final thumbH = (66 * dpr).round();
    final sheetH = (160 * dpr).round();
    final gifUrl = TrainingService.animationImageUrl(
      ex['animation_url']?.toString(),
      null,
    );
    final ImageProvider? previewProvider = gifUrl.isEmpty
        ? null
        : TrainingService.gifProvider(
            gifUrl,
            cacheWidth: thumbW,
            cacheHeight: thumbH,
          );
    if (gifUrl.isNotEmpty) {
      // Warm the sheet size without blocking UI.
      TrainingService.warmGif(
        context,
        gifUrl,
        cacheHeight: sheetH,
      ).catchError((_) {});
    }
    final days = program?['days'];
    Map<String, dynamic> exerciseWithDay = ex;
    if (days is List && selectedDay >= 0 && selectedDay < days.length) {
      final day = days[selectedDay];
      if (day is Map) {
        exerciseWithDay = Map<String, dynamic>.from(ex);
        exerciseWithDay['training_day_id'] = day['day_id'];
        exerciseWithDay['training_day_label'] = day['day_label'];
        exerciseWithDay['training_day_index'] = selectedDay;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: false,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 1.0,
        child: ExerciseSessionSheet(
          exercise: exerciseWithDay,
          completedExerciseNames: completedExerciseNames,
          onFinished: () {
            if (_tabIndex == 0 && mounted) {
              setState(() {
                _showExRestPanel = true;
                if (!_exRestActive) {
                  _exRestRemaining = _exRestPresetSeconds;
                }
              });
            }
            unawaited(_loadProgram());
            _loadWorkoutTimer();
          },
          onStarted: () => _markExerciseInProgress(exerciseWithDay),
          previewProvider: previewProvider,
          showSessionOnOpen: true,
        ),
      ),
    );
    if (!mounted) return;
    await _loadWorkoutTimer();
    await _refreshInProgressExercises();
  }

  void _markExerciseInProgress(Map<String, dynamic> ex) {
    final id = _programExerciseId(ex);
    final name = _normalizeExerciseName(ex['exercise_name']);
    final rawDayIndex = ex['training_day_index'];
    final dayIndex = rawDayIndex is int
        ? rawDayIndex
        : (rawDayIndex is num
              ? rawDayIndex.toInt()
              : int.tryParse(rawDayIndex?.toString() ?? ''));
    if (!mounted) return;
    setState(() {
      if (id != null) {
        _inProgressExerciseIds.add(id);
      }
      if (name.isNotEmpty) {
        _activeSessionExerciseName = name;
      }
      if (dayIndex != null && dayIndex >= 0) {
        _workoutDayIndex = dayIndex;
      }
    });
  }

  void _openTrainTab() {
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
    }
  }

  Future<void> _openCardioTab() async {
    final ok = await ConsentManager.requestBackgroundLocationJIT();
    if (!ok && mounted) {
      AppToast.show(
        context,
        "Location permission is required to show your position on the cardio map.",
        type: AppToastType.info,
      );
    }
    if (!mounted) return;
    setState(() {
      _tabIndex = 1;
      _cardioBuilt = true;
    });
  }

  Future<void> _openReplaceSheet(Map<String, dynamic> ex) async {
    final userId = _userId;
    if (userId == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReplaceExerciseSheet(userId: userId, programExercise: ex),
    );

    if (changed == true) {
      // Try to sync queued actions (in case replace was queued)
      try {
        await ExerciseActionQueue.syncQueue();
      } catch (_) {
        // Ignore sync errors
      }
      await _loadProgram();
    }
  }

  bool _isCardioExercise(Map<String, dynamic> ex) {
    String? _str(dynamic v) => v == null ? null : v.toString().toLowerCase();

    final animationName = _str(ex['animation_name']) ?? '';
    // Trust explicit cardio tag in animation_name (e.g., "Cardio - ...")
    return animationName.startsWith('cardio -');
  }

  DateTime _weekStartMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final daysSinceMonday = (day.weekday + 6) % 7;
    return day.subtract(Duration(days: daysSinceMonday));
  }

  DateTime _weekEndSunday(DateTime d) {
    final start = _weekStartMonday(d);
    return start.add(const Duration(days: 6));
  }

  String _dateToken(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) {
      final intVal = value.toInt();
      if (intVal > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intVal);
      }
      if (intVal > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
      }
    }
    return null;
  }

  bool _flagTrue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == "true" || s == "yes" || s == "y" || s == "t" || s == "1")
      return true;
    final numeric = num.tryParse(s);
    if (numeric != null) return numeric != 0;
    return !(s == "false" || s == "f" || s == "no" || s == "n" || s == "0");
  }

  bool _isInWeek(DateTime date, DateTime weekStart, DateTime weekEnd) {
    return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
  }

  bool _complianceCompletedForWeek(
    dynamic compliance,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (compliance == null) return false;
    if (compliance is Map) {
      final loggedAt = _parseDateTime(
        compliance['logged_at'] ??
            compliance['completed_at'] ??
            compliance['updated_at'] ??
            compliance['performed_at'],
      );
      if (loggedAt == null) return false;
      if (!_isInWeek(loggedAt, weekStart, weekEnd)) return false;
      final flags = [
        compliance['completed'],
        compliance['is_completed'],
        compliance['performed_sets'],
        compliance['performed_reps'],
        compliance['performed_time_seconds'],
        if (compliance['status'] != null)
          compliance['status'].toString().toLowerCase().contains("complete") ||
              compliance['status'].toString().toLowerCase().contains("done") ||
              compliance['status'].toString().toLowerCase().contains("finish"),
      ];
      return flags.any(_flagTrue);
    }
    if (compliance is Iterable) {
      return compliance.any(
        (item) => _complianceCompletedForWeek(item, weekStart, weekEnd),
      );
    }
    if (compliance is String) {
      try {
        final decoded = jsonDecode(compliance);
        return _complianceCompletedForWeek(decoded, weekStart, weekEnd);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  DateTime? _exerciseCompletionDate(Map<String, dynamic> ex) {
    final candidates = [
      ex['logged_at'],
      ex['completed_at'],
      ex['updated_at'],
      ex['performed_at'],
      ex['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isExerciseCompletedForWeek(
    Map<String, dynamic> ex,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (_complianceCompletedForWeek(
          ex['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(ex['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final completionDate = _exerciseCompletionDate(ex);
    if (completionDate == null ||
        !_isInWeek(completionDate, weekStart, weekEnd)) {
      return false;
    }

    final flags = [
      ex['is_completed'],
      ex['completed'],
      ex['program_compliance_completed'],
      ex['performed_sets'],
      ex['performed_reps'],
      ex['performed_time_seconds'],
      ex['weight_used'],
    ];
    return flags.any(_flagTrue);
  }

  bool _isDayCompletedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final flags = [
      day['is_completed'],
      day['completed'],
      day['program_compliance_completed'],
    ];
    if (flags.any(_flagTrue)) return true;
    if (_complianceCompletedForWeek(
          day['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(day['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    for (final ex in exercises) {
      if (ex is Map<String, dynamic>) {
        if (!_isExerciseCompletedForWeek(ex, weekStart, weekEnd)) return false;
      } else if (ex is Map) {
        if (!_isExerciseCompletedForWeek(
          Map<String, dynamic>.from(ex),
          weekStart,
          weekEnd,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  bool _isDayWorkedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final flags = [
      day['is_completed'],
      day['completed'],
      day['program_compliance_completed'],
    ];
    if (flags.any(_flagTrue)) return true;
    if (_complianceCompletedForWeek(
          day['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(day['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    for (final ex in exercises) {
      if (ex is Map<String, dynamic>) {
        if (_isExerciseCompletedForWeek(ex, weekStart, weekEnd)) return true;
      } else if (ex is Map) {
        if (_isExerciseCompletedForWeek(
          Map<String, dynamic>.from(ex),
          weekStart,
          weekEnd,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  String _dayCompletionKey(
    Map<String, dynamic> day,
    int index,
    DateTime weekStart,
  ) {
    final rawId =
        day['day_id'] ??
        day['id'] ??
        day['day_label'] ??
        day['day_name'] ??
        "day_${index + 1}";
    final safeId = rawId.toString().replaceAll(RegExp(r'\s+'), '_');
    return "${_dateToken(weekStart)}_$safeId";
  }

  String _finishedDayStorageKey(int userId, String dayKey) {
    return "train_day_finished_u${userId}_$dayKey";
  }

  String _finishedDayStoragePrefix(int userId, String weekToken) {
    return "train_day_finished_u${userId}_${weekToken}_";
  }

  Map<String, dynamic>? _dayAtIndex(int dayIndex) {
    final days = program?['days'];
    if (days is! List || dayIndex < 0 || dayIndex >= days.length) return null;
    final rawDay = days[dayIndex];
    if (rawDay is Map<String, dynamic>) return rawDay;
    if (rawDay is Map) return Map<String, dynamic>.from(rawDay);
    return null;
  }

  Future<void> _refreshProgramForCompletionCheck() async {
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    try {
      final data = await TrainingService.fetchActiveProgram(userId);
      final serverDays = data['days'];
      final serverDayCount = serverDays is List ? serverDays.length : 0;
      final orderResult = serverDays is List
          ? _buildDayOrder(serverDays)
          : const _DayOrderResult(order: [], completedByIndex: []);
      if (!mounted) return;
      setState(() {
        program = data;
        _dayOrder = orderResult.order;
        _dayCompletedByIndex = orderResult.completedByIndex;
        selectedDay = _firstDayInOrder(orderResult, serverDayCount);
        _rebuildExerciseLists();
      });
    } catch (_) {
      // Keep current snapshot if refresh fails.
    }
  }

  bool _isExerciseCompletedSimple(Map<String, dynamic> ex) {
    if (_flagTrue(ex['is_completed']) ||
        _flagTrue(ex['completed']) ||
        _flagTrue(ex['program_compliance_completed']) ||
        _flagTrue(ex['performed_sets']) ||
        _flagTrue(ex['performed_reps']) ||
        _flagTrue(ex['performed_time_seconds']) ||
        _flagTrue(ex['weight_used'])) {
      return true;
    }
    final pc = ex['program_compliance'];
    if (pc is Map) {
      return _flagTrue(pc['completed']) ||
          _flagTrue(pc['is_completed']) ||
          _flagTrue(pc['performed_sets']) ||
          _flagTrue(pc['performed_reps']) ||
          _flagTrue(pc['performed_time_seconds']) ||
          _flagTrue(pc['weight_used']);
    }
    return false;
  }

  bool _isDayFullyCompletedForCurrentWeek(int dayIndex) {
    final day = _dayAtIndex(dayIndex);
    if (day == null) return false;
    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    final now = DateTime.now();
    final weekStart = _weekStartMonday(now);
    final weekEnd = _weekEndSunday(now);
    var hasTrainExercise = false;
    for (final rawEx in exercises) {
      Map<String, dynamic>? ex;
      if (rawEx is Map<String, dynamic>) {
        ex = rawEx;
      } else if (rawEx is Map) {
        ex = Map<String, dynamic>.from(rawEx);
      }
      if (ex == null) continue;
      if (_isCardioExercise(ex)) continue;
      hasTrainExercise = true;
      final completed =
          _isExerciseCompletedForWeek(ex, weekStart, weekEnd) ||
          _isExerciseCompletedSimple(ex);
      if (!completed) return false;
    }
    return hasTrainExercise;
  }

  bool _isDayFinishedForCurrentWeek(
    Map<String, dynamic> day,
    int index,
    DateTime weekStart,
  ) {
    final key = _dayCompletionKey(day, index, weekStart);
    return _finishedDayKeysForWeek.contains(key);
  }

  Future<void> _loadFinishedDaysForCurrentWeek() async {
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) {
      _finishedDayKeysForWeek = <String>{};
      return;
    }
    final sp = await SharedPreferences.getInstance();
    final weekToken = _dateToken(_weekStartMonday(DateTime.now()));
    final prefix = _finishedDayStoragePrefix(userId, weekToken);
    final markerPrefix = "train_day_finished_u${userId}_";
    final loaded = <String>{};
    for (final key in sp.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      if (sp.getBool(key) != true) continue;
      loaded.add(key.substring(markerPrefix.length));
    }
    _finishedDayKeysForWeek = loaded;
  }

  Future<void> _markDayFinishedForCurrentWeek(int dayIndex) async {
    final day = _dayAtIndex(dayIndex);
    if (day == null) return;
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final weekStart = _weekStartMonday(DateTime.now());
    final dayKey = _dayCompletionKey(day, dayIndex, weekStart);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_finishedDayStorageKey(userId, dayKey), true);
    _finishedDayKeysForWeek = {..._finishedDayKeysForWeek, dayKey};
  }

  Future<void> _clearDayFinishedForCurrentWeek(int dayIndex) async {
    final day = _dayAtIndex(dayIndex);
    if (day == null) return;
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final weekStart = _weekStartMonday(DateTime.now());
    final dayKey = _dayCompletionKey(day, dayIndex, weekStart);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_finishedDayStorageKey(userId, dayKey));
    await sp.remove("train_day_completed_popup_u${userId}_$dayKey");
    _finishedDayKeysForWeek = _finishedDayKeysForWeek
        .where((key) => key != dayKey)
        .toSet();
  }

  Future<void> _maybeShowDayCompletedPopup() async {
    final index = _pendingCompletionDayIndex;
    _pendingCompletionDayIndex = null;
    final data = program;
    if (index == null || data == null) return;
    final days = data['days'];
    if (days is! List || index < 0 || index >= days.length) return;
    final day = days[index];
    if (day is! Map<String, dynamic>) return;

    final now = DateTime.now();
    final weekStart = _weekStartMonday(now);
    final dayKey = _dayCompletionKey(day, index, weekStart);
    if (!_finishedDayKeysForWeek.contains(dayKey)) return;

    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final key = "train_day_completed_popup_u${userId}_$dayKey";
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);

    if (!mounted) return;
    final label = (day['day_label'] ?? 'Training day').toString();
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingDayCompleteSheet(dayLabel: label),
    );
  }

  Widget _tabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2D7CFF)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF2D7CFF) : Colors.white24,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (loading && program == null) {
      return _buildLoadingSkeleton(context);
    }

    if (program == null) {
      return Center(child: Text(t.translate("no_active_training_program")));
    }

    final List days = program!['days'] ?? [];
    final dayOrder = _effectiveDayOrder(days);
    final completedInOrder = dayOrder
        .map(
          (i) => (i >= 0 && i < _dayCompletedByIndex.length)
              ? _dayCompletedByIndex[i]
              : false,
        )
        .toList();
    final disableTrainingToday = _cardioLockToday || _isDeactivated;
    final workoutLockDayIndex =
        (_workoutStartMs != null && _workoutDayIndex != null)
        ? _workoutDayIndex
        : null;
    final disabledInOrder = List<bool>.generate(dayOrder.length, (i) {
      if (disableTrainingToday) return true;
      if (workoutLockDayIndex == null) return false;
      final actualDayIndex = dayOrder[i];
      return actualDayIndex != workoutLockDayIndex;
    });
    final notesInOrder = List<String?>.generate(dayOrder.length, (i) {
      if (_isDeactivated) return "Account is deactivated";
      if (disableTrainingToday) return "Cardio 15+ min today";
      if (workoutLockDayIndex == null) return null;
      final actualDayIndex = dayOrder[i];
      if (actualDayIndex == workoutLockDayIndex) return null;
      return "Workout in progress";
    });

    if (days.isEmpty) {
      return Center(child: Text(t.translate("no_active_training_program")));
    }

    if (selectedDay >= days.length) {
      selectedDay = 0;
    }

    final currentDay = days[selectedDay];
    final selectedDisplayIndex = dayOrder.indexOf(selectedDay);
    final safeDisplayIndex = selectedDisplayIndex >= 0
        ? selectedDisplayIndex
        : 0;
    final workoutDisplayIndex =
        (_workoutStartMs != null && _workoutDayIndex != null)
        ? dayOrder.indexOf(_workoutDayIndex!)
        : -1;
    final safeWorkoutDisplayIndex = workoutDisplayIndex >= 0
        ? workoutDisplayIndex
        : null;

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOffline)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.translate("offline_mode") ?? "Offline Mode",
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isDeactivated)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        "Account is deactivated. Training actions are disabled until you reactivate.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  SectionHeader(title: t.translate("training")),
                  const SizedBox(height: 12),
                  if (_tabIndex == 0) ...[
                    Text(
                      currentDay['day_label'] ?? "",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_workoutStartMs != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2D7CFF).withOpacity(0.15),
                            const Color(0xFF2D7CFF).withOpacity(0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF2D7CFF).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Color(0xFF2D7CFF),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Workout",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  _formatWorkoutTime(_workoutElapsedSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _finishingWorkout
                                ? null
                                : _finishWorkout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade400,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: _finishingWorkout
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    "Finish Workout",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_tabIndex == 0 &&
                      (_showExRestPanel || _exRestActive)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _exRestActive
                                ? Icons.hourglass_bottom
                                : Icons.timer_outlined,
                            color: _exRestActive
                                ? Colors.orangeAccent
                                : Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Between exercises",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _exRestActive
                                      ? _formatRestTime(_exRestRemaining)
                                      : "Rest ${_formatRestTime(_exRestPresetSeconds)}",
                                  style: TextStyle(
                                    color: _exRestActive
                                        ? Colors.orangeAccent
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: _exRestActive ? 22 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_exRestActive)
                            OutlinedButton(
                              onPressed: _skipExRest,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: const Text("Skip"),
                            )
                          else ...[
                            IconButton(
                              onPressed: _setCustomExRestPreset,
                              tooltip: "Custom rest",
                              icon: const Icon(
                                Icons.tune,
                                color: Colors.white70,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _startExRestCountdown,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent
                                    .withOpacity(0.2),
                                foregroundColor: Colors.orangeAccent,
                                elevation: 0,
                              ),
                              child: const Text("Start"),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!_exRestActive) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [10, 15, 30, 45, 60].map((s) {
                          final active = _exRestPresetSeconds == s;
                          return InkWell(
                            onTap: () => _setExRestPreset(s),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.orangeAccent.withOpacity(0.22)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active
                                      ? Colors.orangeAccent.withOpacity(0.45)
                                      : Colors.white.withOpacity(0.16),
                                ),
                              ),
                              child: Text(
                                "${s}s",
                                style: TextStyle(
                                  color: active
                                      ? Colors.orangeAccent
                                      : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      _tabButton(
                        label: "Train",
                        active: _tabIndex == 0,
                        onTap: _openTrainTab,
                      ),
                      const SizedBox(width: 10),
                      _tabButton(
                        label: "Cardio",
                        active: _tabIndex == 1,
                        onTap: _openCardioTab,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: Colors.black87,
                    onRefresh: _loadProgram,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        DaySelector(
                          labels: dayOrder.map<String>((i) {
                            final d = days[i];
                            if (d is Map) {
                              return d['day_label']?.toString() ?? '';
                            }
                            return '';
                          }).toList(),
                          completed: completedInOrder,
                          disabled: disabledInOrder,
                          notes: notesInOrder,
                          workoutInProgress: _workoutStartMs != null,
                          workoutInProgressIndex: safeWorkoutDisplayIndex,
                          selectedIndex: safeDisplayIndex,
                          onSelect: (i) {
                            final nextIndex = (i >= 0 && i < dayOrder.length)
                                ? dayOrder[i]
                                : i;
                            if (_workoutStartMs != null &&
                                _workoutDayIndex != null &&
                                nextIndex != _workoutDayIndex) {
                              AppToast.show(
                                context,
                                "Finish the current workout before switching days.",
                                type: AppToastType.info,
                              );
                              return;
                            }
                            setState(() {
                              selectedDay = nextIndex;
                              _rebuildExerciseLists();
                            });
                            _preloadExerciseGifsForCurrentDay();
                            unawaited(_refreshInProgressExercises());
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.translate("training_exercise_list_title"),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final currentProgram = program;
                                if (currentProgram == null) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TrainingHistoryPage(
                                      program: currentProgram,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text("History"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.translate("training_exercise_list_sub"),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        if (_trainExercises.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                t.translate("rest_day"),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          )
                        else
                          ..._trainExercises.asMap().entries.map<Widget>((
                            entry,
                          ) {
                            final ex = entry.value;
                            final rawId =
                                ex['program_exercise_id'] ??
                                ex['exercise_id'] ??
                                ex['exercise_name'] ??
                                entry.key;
                            final programExerciseId = _programExerciseId(ex);
                            final normalizedName = _normalizeExerciseName(
                              ex['exercise_name'],
                            );
                            final inProgressById =
                                programExerciseId != null &&
                                _inProgressExerciseIds.contains(
                                  programExerciseId,
                                );
                            final inProgressByName =
                                _activeSessionExerciseName != null &&
                                normalizedName.isNotEmpty &&
                                normalizedName == _activeSessionExerciseName;
                            final exKey = ValueKey("train_ex_$rawId");
                            return Padding(
                              key: exKey,
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ExerciseCard(
                                exercise: ex,
                                onTap: () => _startExerciseFlow(ex),
                                onReplace: () => _openReplaceSheet(ex),
                                disabled: disableTrainingToday,
                                inProgress: inProgressById || inProgressByName,
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: Colors.black87,
                    onRefresh: _loadProgram,
                    child: _cardioBuilt
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              const SizedBox(height: 8),
                              CardioTab(
                                exercises: _cardioExercises,
                                onStart: _startExerciseFlow,
                                onReplace: _openReplaceSheet,
                                readOnlyLocked: _isDeactivated,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final t = AppLocalizations.of(context);

    Widget skeletonLine({double width = 120, double height = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    Widget skeletonCard() {
      return Container(
        height: 86,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
      );
    }

    Widget skeletonPill({double width = 110}) {
      return Container(
        height: 36,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: t.translate("training")),
                  const SizedBox(height: 12),
                  skeletonLine(width: 140, height: 16),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      skeletonPill(width: 120),
                      const SizedBox(width: 10),
                      skeletonPill(width: 120),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  skeletonLine(width: 180, height: 14),
                  const SizedBox(height: 6),
                  skeletonLine(width: 240, height: 12),
                  const SizedBox(height: 16),
                  for (int i = 0; i < 4; i++) skeletonCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
