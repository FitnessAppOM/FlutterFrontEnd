import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/components/taqa_action_controls.dart';
import 'package:taqaproject/TaqaUI/components/taqa_steps_ui.dart';
import 'package:taqaproject/TaqaUI/components/taqa_set_row_edit_dialog.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import '../../widgets/training/exercise_card.dart';
import '../../widgets/training/exercise_feedback_sheet.dart';
import '../../widgets/training/exercise_instruction_dialog.dart';
import '../../widgets/training/exercise_session_sheet.dart';
import '../../widgets/cardio/cardio_exercise_utils.dart';
import '../../widgets/cardio/cardio_resume_banner.dart';
import '../../core/account_storage.dart';
import '../../core/training_regeneration_flag.dart';
import '../../localization/app_localizations.dart';
import '../../services/auth/profile_service.dart';
import '../../services/training/training_service.dart';
import '../../widgets/training/replace_exercise_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../consents/consent_manager.dart';
import '../../screens/training/training_history_page.dart';
import '../../screens/cardio/cardio_history_page.dart';
import '../../widgets/training/training_day_complete_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/training/training_progress_storage.dart';
import '../../services/training/training_activity_service.dart';
import '../../services/training/cardio_exercises_storage.dart';
import '../../services/health/workout_health_sync_service.dart';
import '../../services/training/training_reset_coordinator.dart';
import '../../services/training/training_network_resilience.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => TrainPageState();
}

class _TrainingDayLiveState {
  const _TrainingDayLiveState({
    required this.inProgressExerciseIds,
    required this.inProgressStartMsById,
    required this.activeSessionExerciseName,
    required this.sessionCompletedExerciseNames,
    required this.showWorkoutTimer,
    required this.workoutTimeText,
    required this.finishingWorkout,
    required this.showRestPanel,
    required this.restActive,
    required this.restTimeText,
    required this.activeRestPreset,
  });

  final Set<int> inProgressExerciseIds;
  final Map<int, int> inProgressStartMsById;
  final String? activeSessionExerciseName;
  final Set<String> sessionCompletedExerciseNames;
  final bool showWorkoutTimer;
  final String workoutTimeText;
  final bool finishingWorkout;
  final bool showRestPanel;
  final bool restActive;
  final String restTimeText;
  final int activeRestPreset;
}

class _TrainingDayExercisesPage extends StatefulWidget {
  const _TrainingDayExercisesPage({
    required this.dayLabel,
    required this.exercises,
    required this.readDisabledState,
    required this.readDayNoteState,
    required this.readLiveState,
    required this.readHistoryCompletedExerciseNames,
    required this.programExerciseIdOf,
    required this.normalizeExerciseName,
    required this.onStartExercise,
    required this.onExerciseFinished,
    required this.onReplaceExercise,
    required this.onWorkoutSessionClosed,
    required this.onFinishWorkout,
    required this.onSkipRest,
    required this.onStartRest,
    required this.onSetCustomRest,
    required this.restPresets,
    required this.onSelectRestPreset,
  });

  final String dayLabel;
  final List<Map<String, dynamic>> exercises;
  final bool Function() readDisabledState;
  final String? Function() readDayNoteState;
  final _TrainingDayLiveState Function() readLiveState;
  final Set<String> Function() readHistoryCompletedExerciseNames;
  final int? Function(Map<String, dynamic>) programExerciseIdOf;
  final String Function(dynamic) normalizeExerciseName;
  final Future<void> Function(
    Map<String, dynamic> exercise, {
    required int sets,
    required int reps,
  })
  onStartExercise;
  final Future<void> Function(Map<String, dynamic> exercise) onExerciseFinished;
  final Future<void> Function(Map<String, dynamic>) onReplaceExercise;
  final Future<void> Function() onWorkoutSessionClosed;
  final Future<void> Function() onFinishWorkout;
  final VoidCallback onSkipRest;
  final VoidCallback onStartRest;
  final VoidCallback onSetCustomRest;
  final List<int> restPresets;
  final void Function(int seconds) onSelectRestPreset;

  @override
  State<_TrainingDayExercisesPage> createState() =>
      _TrainingDayExercisesPageState();
}

class _TrainingDayExercisesPageState extends State<_TrainingDayExercisesPage> {
  Timer? _refreshTimer;

  Route<T> _buildLauncherRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        );
        return SlideTransition(
          position: offsetTween.animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Opens the workout launcher screen (same as the START WORKOUT button). The
  // launcher auto-focuses any in-progress exercise, so this doubles as "resume".
  Future<void> _openWorkoutLauncher() async {
    final live = widget.readLiveState();
    await Navigator.of(context).push(
      _buildLauncherRoute(
        _WorkoutLauncherPage(
          dayLabel: widget.dayLabel,
          exercises: widget.exercises,
          restSeconds: live.activeRestPreset,
          readLiveState: widget.readLiveState,
          readHistoryCompletedExerciseNames:
              widget.readHistoryCompletedExerciseNames,
          inProgressExerciseIds: live.inProgressExerciseIds,
          activeSessionExerciseName: live.activeSessionExerciseName,
          onStartExercise: widget.onStartExercise,
          onExerciseFinished: widget.onExerciseFinished,
          onReplaceExercise: widget.onReplaceExercise,
        ),
      ),
    );
    if (!mounted) return;
    await widget.onWorkoutSessionClosed();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.readLiveState();
    final isDisabled = widget.readDisabledState();
    final dayNote = widget.readDayNoteState();
    // Leaving mid-workout is allowed: the session keeps running and the
    // persistent minimized workout bar (in the app shell) lets the user return.
    // Only block while a finish is actively in flight to avoid a torn state.
    final blockLeave = !isDisabled && live.finishingWorkout;
    return PopScope(
      canPop: !blockLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !blockLeave) return;
        AppToast.show(
          context,
          "Finishing workout — one moment.",
          type: AppToastType.info,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            widget.dayLabel,
            style: const TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 2.5,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
          foregroundColor: TaqaUiColors.unnamedColor1c1d17,
          elevation: 0,
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Include the bottom safe-area inset so the START WORKOUT button
          // isn't covered by the Android system nav bar.
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          children: [
            if (live.showWorkoutTimer) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF1C1D17).withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF1C1D17), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Workout",
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                          Text(
                            live.workoutTimeText,
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: live.finishingWorkout
                          ? null
                          : () => widget.onFinishWorkout(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaqaUiColors.white,
                        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: live.finishingWorkout
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              "Finish",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ],
            if (live.showRestPanel) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF1C1D17).withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      live.restActive
                          ? Icons.hourglass_bottom
                          : Icons.timer_outlined,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Between exercises",
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                          Text(
                            live.restTimeText,
                            style: const TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (live.restActive)
                      OutlinedButton(
                        onPressed: widget.onSkipRest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                          side: const BorderSide(color: Color(0x4D1C1D17)),
                        ),
                        child: const Text("Skip"),
                      )
                    else ...[
                      IconButton(
                        onPressed: widget.onSetCustomRest,
                        tooltip: "Custom rest",
                        icon: const Icon(Icons.tune, color: Color(0xFF1C1D17)),
                      ),
                      ElevatedButton(
                        onPressed: widget.onStartRest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TaqaUiColors.white,
                          foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                        ),
                        child: const Text("Start"),
                      ),
                    ],
                  ],
                ),
              ),
              if (!live.restActive) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.restPresets.map((s) {
                    final active = live.activeRestPreset == s;
                    return InkWell(
                      onTap: () => widget.onSelectRestPreset(s),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFE4E93B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x4D1C1D17)),
                        ),
                        child: Text(
                          "${s}s",
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (dayNote != null && dayNote.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  dayNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: TaqaUiColors.unnamedColor1c1d17.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  AppLocalizations.of(context).translate("rest_day"),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: TaqaUiColors.unnamedColor1c1d17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...(() {
                final historyCompletedExerciseNames = widget
                    .readHistoryCompletedExerciseNames();
                final items = widget.exercises.asMap().entries.map((entry) {
                  final ex = entry.value;
                  final rawId =
                      ex['program_exercise_id'] ??
                      ex['exercise_id'] ??
                      ex['exercise_name'] ??
                      entry.key;
                  final programExerciseId = widget.programExerciseIdOf(ex);
                  final normalizedName = widget.normalizeExerciseName(
                    ex['exercise_name'],
                  );
                  final inProgressById =
                      programExerciseId != null &&
                      live.inProgressExerciseIds.contains(programExerciseId);
                  final inProgressByName =
                      live.activeSessionExerciseName != null &&
                      normalizedName.isNotEmpty &&
                      normalizedName == live.activeSessionExerciseName;
                  final locallyCompleted =
                      normalizedName.isNotEmpty &&
                      live.sessionCompletedExerciseNames.contains(
                        normalizedName,
                      );
                  final doneFromHistory =
                      normalizedName.isNotEmpty &&
                      historyCompletedExerciseNames.contains(normalizedName);
                  final done = locallyCompleted || doneFromHistory;
                  return <String, dynamic>{
                    'index': entry.key,
                    'exercise': ex,
                    'rawId': rawId,
                    'programExerciseId': programExerciseId,
                    'inProgress': inProgressById || inProgressByName,
                    'done': done,
                  };
                }).toList();

                items.sort((a, b) {
                  final aDone = a['done'] == true;
                  final bDone = b['done'] == true;
                  if (aDone == bDone) {
                    return (a['index'] as int).compareTo(b['index'] as int);
                  }
                  return aDone ? 1 : -1;
                });

                return items.map((item) {
                  final ex = item['exercise'] as Map<String, dynamic>;
                  final rawId = item['rawId'];
                  final done = item['done'] == true;
                  final inProgress = item['inProgress'] == true;
                  final programExerciseId = item['programExerciseId'] as int?;
                  final sessionStartMs =
                      (inProgress && programExerciseId != null)
                      ? live.inProgressStartMsById[programExerciseId]
                      : null;
                  final exKey = ValueKey("day_ex_$rawId");
                  return Padding(
                    key: exKey,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ExerciseCard(
                      exercise: ex,
                      onReplace: () => unawaited(widget.onReplaceExercise(ex)),
                      disabled: isDisabled,
                      completedOverride: done,
                      forceCompleted: done,
                      inProgress: inProgress,
                      showReplace: !live.showWorkoutTimer,
                      // Show the (heaviest completed) weight on finished cards;
                      // it persists via weight_used so it stays on every load.
                      showWeight: done,
                      // Resume opens the same workout launcher the START WORKOUT
                      // button does (it auto-focuses the in-progress exercise),
                      // with a live per-exercise timer on the button.
                      onResume: (inProgress && !done)
                          ? () => unawaited(_openWorkoutLauncher())
                          : null,
                      sessionStartMs: sessionStartMs,
                    ),
                  );
                });
              })(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDisabled || widget.exercises.isEmpty
                    ? null
                    : () => unawaited(_openWorkoutLauncher()),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFE4E93B),
                  foregroundColor: const Color(0xFF1C1D17),
                  disabledBackgroundColor: const Color(0x80E4E93B),
                  disabledForegroundColor: const Color(0x801C1D17),
                  minimumSize: Size(double.infinity, TaqaUiScale.h(45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: TaqaUiScale.radius(5),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: TaqaUiScale.w(5)),
                ),
                child: Text(
                  "START WORKOUT",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(10),
                    fontWeight: FontWeight.w600,
                    height: 12 / 10,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutLauncherPage extends StatefulWidget {
  const _WorkoutLauncherPage({
    required this.dayLabel,
    required this.exercises,
    required this.restSeconds,
    required this.readLiveState,
    required this.readHistoryCompletedExerciseNames,
    required this.inProgressExerciseIds,
    required this.activeSessionExerciseName,
    required this.onStartExercise,
    required this.onExerciseFinished,
    required this.onReplaceExercise,
  });

  final String dayLabel;
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;
  final _TrainingDayLiveState Function() readLiveState;
  final Set<String> Function() readHistoryCompletedExerciseNames;
  final Set<int> inProgressExerciseIds;
  final String? activeSessionExerciseName;
  final Future<void> Function(
    Map<String, dynamic> exercise, {
    required int sets,
    required int reps,
  })
  onStartExercise;
  final Future<void> Function(Map<String, dynamic> exercise) onExerciseFinished;
  final Future<void> Function(Map<String, dynamic> exercise) onReplaceExercise;

  @override
  State<_WorkoutLauncherPage> createState() => _WorkoutLauncherPageState();
}

class _WorkoutLauncherPageState extends State<_WorkoutLauncherPage> {
  int? _activeExerciseIndex;
  final Set<String> _locallyCompletedExerciseNames = <String>{};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activeExerciseIndex = _resolveActiveExerciseIndex();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  int? _programExerciseId(Map<String, dynamic> ex) {
    final raw = ex['program_exercise_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  int? _resolveActiveExerciseIndex() {
    for (var i = 0; i < widget.exercises.length; i++) {
      final id = _programExerciseId(widget.exercises[i]);
      if (id != null && widget.inProgressExerciseIds.contains(id)) {
        return i;
      }
    }
    final activeName = (widget.activeSessionExerciseName ?? '')
        .trim()
        .toLowerCase();
    if (activeName.isNotEmpty) {
      for (var i = 0; i < widget.exercises.length; i++) {
        final name = (widget.exercises[i]['exercise_name'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (name.isNotEmpty && name == activeName) {
          return i;
        }
      }
    }
    return null;
  }

  Future<void> _finishExerciseFromLauncher(int index) async {
    final ex = widget.exercises[index];
    final name = (ex['exercise_name'] ?? '').toString().trim().toLowerCase();
    if (name.isNotEmpty) {
      _locallyCompletedExerciseNames.add(name);
    }
    await widget.onExerciseFinished(ex);
    if (!mounted) return;
    setState(() {
      if (_activeExerciseIndex == index) {
        _activeExerciseIndex = null;
      }
    });
  }

  bool _isExerciseDone(Map<String, dynamic> ex) {
    final name = (ex['exercise_name'] ?? '').toString().trim().toLowerCase();
    if (name.isNotEmpty && _locallyCompletedExerciseNames.contains(name)) {
      return true;
    }
    final historyCompletedExerciseNames = widget
        .readHistoryCompletedExerciseNames();
    return name.isNotEmpty && historyCompletedExerciseNames.contains(name);
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  String _exerciseName(Map<String, dynamic> ex, int index) {
    final raw = ex['exercise_name']?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Exercise ${index + 1}';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.readLiveState();
    final sortedEntries = widget.exercises.asMap().entries.toList()
      ..sort((a, b) {
        final aDone = _isExerciseDone(a.value);
        final bDone = _isExerciseDone(b.value);
        if (aDone == bDone) return a.key.compareTo(b.key);
        return aDone ? 1 : -1;
      });
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Android-only system nav bar clearance for the floating workout timer.
    // iPhone already clears it (and adding this would shift the iPhone layout),
    // so gate it to Android.
    final androidNavInset =
        Theme.of(context).platform == TargetPlatform.android
        ? MediaQuery.of(context).viewPadding.bottom
        : 0.0;
    final showFloatingWorkoutTimer = live.showWorkoutTimer;
    final listBottomPadding = showFloatingWorkoutTimer
        ? 110.0 + bottomInset + androidNavInset
        : 20.0 + androidNavInset;

    return Scaffold(
      backgroundColor: const Color(0xFF11130F),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF11130F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.dayLabel,
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView.separated(
            padding: EdgeInsets.fromLTRB(14, 10, 14, listBottomPadding),
            itemCount: sortedEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final sourceIndex = entry.key;
              final ex = entry.value;
              final isDone = _isExerciseDone(ex);
              final sets = _asInt(ex['sets'], fallback: 2).clamp(1, 12);
              final reps = _asInt(ex['reps'], fallback: 8).clamp(1, 200);
              final rir = _asInt(ex['rir'], fallback: 2).clamp(0, 10);
              final name = _exerciseName(ex, sourceIndex);
              final isActive = _activeExerciseIndex == sourceIndex;
              final dimmed = _activeExerciseIndex != null && !isActive;
              return IgnorePointer(
                ignoring: dimmed,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      _WorkoutLauncherExerciseCard(
                        exercise: ex,
                        name: name,
                        sets: sets,
                        reps: reps,
                        rir: rir,
                        restSeconds: widget.restSeconds,
                        isDone: isDone,
                        isActive: isActive,
                        onStarted: () {
                          if (!mounted) return;
                          setState(() => _activeExerciseIndex = sourceIndex);
                        },
                        onFinished: () {
                          unawaited(_finishExerciseFromLauncher(sourceIndex));
                        },
                        onReplace: () =>
                            unawaited(widget.onReplaceExercise(ex)),
                        onStart: ({required int sets, required int reps}) =>
                            widget.onStartExercise(ex, sets: sets, reps: reps),
                      ),
                      if (dimmed)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.24),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (showFloatingWorkoutTimer)
            Positioned(
              left: 14,
              bottom: 14 + bottomInset + androidNavInset,
              child: IgnorePointer(
                ignoring: live.finishingWorkout,
                child: _WorkoutFloatingTimerBar(
                  timeText: live.workoutTimeText,
                  finishing: live.finishingWorkout,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkoutLauncherExerciseCard extends StatefulWidget {
  const _WorkoutLauncherExerciseCard({
    required this.exercise,
    required this.name,
    required this.sets,
    required this.reps,
    required this.rir,
    required this.restSeconds,
    required this.isDone,
    required this.isActive,
    required this.onStarted,
    required this.onFinished,
    required this.onReplace,
    required this.onStart,
  });

  final Map<String, dynamic> exercise;
  final String name;
  final int sets;
  final int reps;
  final int rir;
  final int restSeconds;
  final bool isDone;
  final bool isActive;
  final VoidCallback onStarted;
  final VoidCallback onFinished;
  final VoidCallback onReplace;
  final Future<void> Function({required int sets, required int reps}) onStart;

  @override
  State<_WorkoutLauncherExerciseCard> createState() =>
      _WorkoutLauncherExerciseCardState();
}

class _WorkoutLauncherExerciseCardState
    extends State<_WorkoutLauncherExerciseCard> {
  late List<_LauncherSetRow> _rows;
  bool _starting = false;
  bool _finishingExercise = false;
  bool _exerciseFinished = false;
  bool _restoredProgress = false;
  Timer? _activeTicker;
  int? _exerciseStartedAtMs;
  int? _setStartedAtMs;
  late int _restSeconds;
  bool _restCountdownActive = false;
  int _restRemainingSeconds = 0;
  int _flowSetIndex = 0;
  bool _setInProgress = false;

  @override
  void initState() {
    super.initState();
    _rows = _seedRows();
    _restSeconds = widget.restSeconds;
    _flowSetIndex = _initialFlowSetIndex();
    if (widget.isActive) {
      _setInProgress = true;
      _ensureActiveTimers();
    }
    unawaited(_restoreLauncherProgressState());
  }

  @override
  void didUpdateWidget(covariant _WorkoutLauncherExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (!_restoredProgress) {
        _setInProgress = true;
        _flowSetIndex = _flowSetIndex.clamp(
          0,
          (_rows.length - 1).clamp(0, 999),
        );
        _ensureActiveTimers();
      }
      unawaited(_restoreLauncherProgressState());
    } else if (!widget.isActive && oldWidget.isActive) {
      _activeTicker?.cancel();
      _activeTicker = null;
    }
  }

  @override
  void dispose() {
    unawaited(_saveLauncherProgressState());
    _activeTicker?.cancel();
    super.dispose();
  }

  Future<void> _restoreLauncherProgressState() async {
    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    final state = await TrainingProgressStorage.loadExerciseTimerState(
      programExerciseId,
    );
    if (!mounted) return;
    if (state == null || state['started'] != true) {
      _restoredProgress = false;
      return;
    }

    final savedRows = state['saved_set_rows'];
    final restoredRows = <_LauncherSetRow>[];
    if (savedRows is List) {
      for (final raw in savedRows) {
        if (raw is! Map) continue;
        restoredRows.add(
          _LauncherSetRow(
            setIndex: _toInt(
              raw['set_index'],
              fallback: restoredRows.length + 1,
            ),
            reps: _toInt(raw['reps'], fallback: widget.reps),
            rir: _toInt(raw['rir'], fallback: widget.rir),
            weightKg: _toDouble(raw['weight_kg'], fallback: 0),
            done: _toBool(raw['completed']),
          ),
        );
      }
    }
    if (restoredRows.isNotEmpty) {
      restoredRows.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    }

    final savedAtMs = _toInt(
      state['launcher_saved_at_ms'],
      fallback: DateTime.now().millisecondsSinceEpoch,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final gapSeconds = savedAtMs > 0 ? ((nowMs - savedAtMs) / 1000).floor() : 0;
    final savedRestActive = state['launcher_rest_countdown_active'] == true;
    var restRemaining = _toInt(
      state['launcher_rest_countdown_remaining'],
      fallback: 0,
    );
    var setInProgress = state['launcher_set_in_progress'] == true;
    int? setStartedAtMs = _toInt(
      state['launcher_set_started_at_ms'],
      fallback: 0,
    );
    if (setStartedAtMs <= 0) {
      setStartedAtMs = null;
    }
    if (savedRestActive && restRemaining > 0) {
      restRemaining -= gapSeconds;
      if (restRemaining <= 0) {
        restRemaining = 0;
        setInProgress = true;
        setStartedAtMs = nowMs;
      }
    }

    final savedFlowIndex = _toInt(
      state['launcher_flow_set_index'],
      fallback: 0,
    );
    final clampedFlowIndex = restoredRows.isEmpty
        ? savedFlowIndex.clamp(0, 999)
        : savedFlowIndex.clamp(0, restoredRows.length - 1);

    setState(() {
      if (restoredRows.isNotEmpty) {
        _rows = restoredRows;
      }
      _restSeconds = _toInt(
        state['launcher_rest_seconds'],
        fallback: _restSeconds,
      );
      _flowSetIndex = clampedFlowIndex;
      _setInProgress = setInProgress;
      _restCountdownActive = savedRestActive && restRemaining > 0;
      _restRemainingSeconds = _restCountdownActive ? restRemaining : 0;
      _exerciseStartedAtMs = _toInt(state['start_ms'], fallback: 0);
      if (_exerciseStartedAtMs != null && _exerciseStartedAtMs! <= 0) {
        _exerciseStartedAtMs = null;
      }
      _setStartedAtMs = _setInProgress ? setStartedAtMs : null;
      _restoredProgress = true;
    });

    if (widget.isActive) {
      _ensureActiveTimers();
    }
  }

  Future<void> _saveLauncherProgressState() async {
    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    if (_finishingExercise) return;
    if (_exerciseFinished) return;
    if (!widget.isActive) return;
    if (_exerciseStartedAtMs == null && !widget.isActive) return;

    await TrainingProgressStorage.saveExerciseTimerState(programExerciseId, {
      'started': widget.isActive || _exerciseStartedAtMs != null,
      'paused': false,
      'seconds': _elapsedSecondsSince(_exerciseStartedAtMs),
      'start_ms': _exerciseStartedAtMs,
      'saved_set_rows': _rows
          .map(
            (row) => {
              'set_index': row.setIndex,
              'reps': row.reps,
              'rir': row.rir,
              'weight_kg': row.weightKg,
              'completed': row.done,
            },
          )
          .toList(),
      'has_set_rows': _rows.isNotEmpty,
      'launcher_flow_set_index': _flowSetIndex,
      'launcher_set_in_progress': _setInProgress,
      'launcher_set_started_at_ms': _setStartedAtMs,
      'launcher_rest_seconds': _restSeconds,
      'launcher_rest_countdown_active': _restCountdownActive,
      'launcher_rest_countdown_remaining': _restRemainingSeconds,
      'launcher_saved_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _ensureActiveTimers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _exerciseStartedAtMs ??= now;
    if (_setInProgress) {
      _setStartedAtMs ??= now;
    }
    _activeTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.isActive) return;
      setState(() {
        if (_restCountdownActive && _restRemainingSeconds > 0) {
          _restRemainingSeconds -= 1;
          if (_restRemainingSeconds <= 0) {
            _restRemainingSeconds = 0;
            _restCountdownActive = false;
            _setInProgress = true;
            _setStartedAtMs = DateTime.now().millisecondsSinceEpoch;
          }
        }
      });
      unawaited(_saveLauncherProgressState());
    });
  }

  int _initialFlowSetIndex() {
    if (_rows.isEmpty) return 0;
    return 0;
  }

  int _activeFlowSetIndex() {
    if (_rows.isEmpty) return 0;
    final maxIndex = _rows.length - 1;
    if (_flowSetIndex < 0) return 0;
    if (_flowSetIndex > maxIndex) return maxIndex;
    return _flowSetIndex;
  }

  String _setActionLabel() {
    if (_restCountdownActive && !_setInProgress) {
      return "REST ${_formatMmSs(_restRemainingSeconds)}";
    }
    final setNo = _activeFlowSetIndex() + 1;
    return _setInProgress ? "FINISH SET $setNo" : "START SET $setNo";
  }

  Future<void> _onSetActionPressed() async {
    if (_rows.isEmpty) return;
    final idx = _activeFlowSetIndex();
    if (_setInProgress) {
      final current = _rows[idx];
      if (!current.done) {
        final doneRow = current.copyWith(done: true);
        final nextRows = List<_LauncherSetRow>.from(_rows);
        nextRows[idx] = doneRow;
        if (mounted) {
          setState(() => _rows = nextRows);
        }
        await _persistUpsert(doneRow);
      }

      if (idx >= _rows.length - 1) {
        await _finishExercise();
        return;
      }

      final rest = _restSeconds < 0 ? 0 : _restSeconds;
      if (mounted) {
        setState(() {
          _flowSetIndex = idx + 1;
          _setInProgress = false;
          _setStartedAtMs = null;
          _restCountdownActive = rest > 0;
          _restRemainingSeconds = rest;
        });
      }
      await _saveLauncherProgressState();
      return;
    }

    if (mounted) {
      setState(() {
        _setInProgress = true;
        _restCountdownActive = false;
        _restRemainingSeconds = 0;
        _setStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      });
    }
    _ensureActiveTimers();
    await _saveLauncherProgressState();
  }

  Future<void> _finishExercise() async {
    if (_finishingExercise) return;
    setState(() => _finishingExercise = true);
    final now = DateTime.now();
    try {
      final completedRows = _rows
          .where((row) => row.done)
          .toList(growable: false);
      final sourceRows = completedRows.isNotEmpty ? completedRows : _rows;
      final fallbackRow = _rows.isNotEmpty ? _rows.last : null;
      final lastRow = sourceRows.isNotEmpty ? sourceRows.last : fallbackRow;
      final performedSets = sourceRows.isNotEmpty ? sourceRows.length : 1;
      final performedReps = lastRow?.reps ?? widget.reps;
      final performedRir = lastRow?.rir ?? widget.rir;
      final durationSeconds = _elapsedSecondsSince(_exerciseStartedAtMs);
      // Heaviest weight among COMPLETED sets, so the finished card can show a
      // durable weight that persists across loads (weight_used).
      double maxCompletedWeight = 0;
      for (final row in completedRows) {
        if (row.weightKg > maxCompletedWeight) {
          maxCompletedWeight = row.weightKg;
        }
      }

      // Optimistic: write the performed summary onto the shared exercise map so
      // the day card shows done + weight/sets/reps IMMEDIATELY, without waiting
      // for the whole-day server refresh. (widget.exercise is the same map
      // object the parent reads.)
      widget.exercise['set_rows'] = sourceRows
          .map(
            (row) => {
              'set_index': row.setIndex,
              'reps': row.reps,
              'rir': row.rir,
              'weight_kg': row.weightKg,
              'completed': row.done,
            },
          )
          .toList();
      widget.exercise['performed_sets'] = performedSets;
      widget.exercise['performed_reps'] = performedReps;
      widget.exercise['performed_rir'] = performedRir;
      if (maxCompletedWeight > 0) {
        widget.exercise['weight_used'] = maxCompletedWeight;
        widget.exercise['weight_kg'] = maxCompletedWeight;
      }
      widget.exercise['is_completed'] = true;
      widget.exercise['logged_at'] = now.toIso8601String();

      final programExerciseId = _programExerciseId();

      if (programExerciseId != null) {
        if (maxCompletedWeight > 0) {
          // Persist durably so the weight reappears on every future load.
          // Best-effort: failure here must not block finishing the exercise.
          try {
            await TrainingService.saveWeight(
              programExerciseId,
              maxCompletedWeight,
            );
          } catch (_) {}
        }
        try {
          await TrainingNetworkResilience.withTimeout(
            TrainingService.finishExercise(
              programExerciseId: programExerciseId,
              sets: performedSets > 0 ? performedSets : null,
              reps: performedReps > 0 ? performedReps : null,
              rir: performedRir >= 0 ? performedRir : null,
              durationSeconds: durationSeconds,
              entryDate: now,
            ),
            TrainingNetworkResilience.sheetMutation,
          );
        } catch (_) {
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionFinish,
            programExerciseId: programExerciseId,
            data: {
              "sets": performedSets,
              "reps": performedReps,
              "rir": performedRir,
              "duration_seconds": durationSeconds,
              "entry_date":
                  "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
            },
          );
        }
      }

      final finishedAtMs = DateTime.now().millisecondsSinceEpoch;
      await TrainingProgressStorage.saveLastExerciseFinishedMs(finishedAtMs);
      final exerciseName = (widget.exercise['exercise_name'] ?? widget.name)
          .toString()
          .trim();
      if (exerciseName.isNotEmpty) {
        await TrainingProgressStorage.saveSessionCompletedExerciseName(
          exerciseName,
          finishedAtMs: finishedAtMs,
        );
      }

      _activeTicker?.cancel();
      _activeTicker = null;
      _setInProgress = false;
      _restCountdownActive = false;
      _restRemainingSeconds = 0;
      _exerciseFinished = true;
      if (programExerciseId != null) {
        await TrainingProgressStorage.clearExerciseTimerState(
          programExerciseId,
        );
      }

      await TrainingActivityService.stopSession();
      AccountStorage.notifyTrainingChanged();
      widget.onFinished();
      if (mounted && programExerciseId != null) {
        await showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          barrierColor: const Color(0x66000000),
          backgroundColor: Colors.transparent,
          elevation: 0,
          builder: (_) => ExerciseFeedbackSheet(
            programExerciseId: programExerciseId,
            exerciseName: exerciseName.isNotEmpty ? exerciseName : widget.name,
            onDone: () {},
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _finishingExercise = false);
    }
  }

  void _skipRestCountdown() {
    if (!_restCountdownActive) return;
    setState(() {
      _restCountdownActive = false;
      _restRemainingSeconds = 0;
    });
    unawaited(_saveLauncherProgressState());
  }

  Future<void> _changeRestSeconds() async {
    if (_restCountdownActive) return;
    final options = <int>[10, 15, 30, 45, 60, 90];
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Set rest timer",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((s) {
                    final active = s == _restSeconds;
                    return InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(s),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFE4E93B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x4D1C1D17)),
                        ),
                        child: Text(
                          "${s}s",
                          style: const TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    final txt = await showTaqaTextValueDialog(
                      context: context,
                      title: "Custom rest (seconds)",
                      initialValue: _restSeconds.toString(),
                      keyboardType: TextInputType.number,
                    );
                    final parsed = int.tryParse((txt ?? '').trim());
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop(parsed);
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text("Custom"),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || selected <= 0) return;
    if (!mounted) return;
    setState(() {
      _restSeconds = selected;
      if (_restCountdownActive && _restRemainingSeconds > selected) {
        _restRemainingSeconds = selected;
      }
    });
    await _saveLauncherProgressState();
  }

  int _elapsedSecondsSince(int? startedAtMs) {
    if (startedAtMs == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - startedAtMs;
    if (diffMs <= 0) return 0;
    return (diffMs / 1000).floor();
  }

  String _formatMmSs(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mm = (safe ~/ 60).toString().padLeft(2, '0');
    final ss = (safe % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  int? _programExerciseId() {
    final raw = widget.exercise['program_exercise_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  double _toDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = (value ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 't';
  }

  List<_LauncherSetRow> _seedRows() {
    final rawRows = widget.exercise['set_rows'];
    final out = <_LauncherSetRow>[];
    if (rawRows is List && rawRows.isNotEmpty) {
      for (final raw in rawRows) {
        if (raw is! Map) continue;
        final idx = _toInt(raw['set_index'], fallback: out.length + 1);
        out.add(
          _LauncherSetRow(
            setIndex: idx > 0 ? idx : out.length + 1,
            reps: _toInt(raw['reps'], fallback: widget.reps),
            rir: _toInt(raw['rir'], fallback: widget.rir),
            weightKg: _toDouble(raw['weight_kg'], fallback: 0),
            done: _toBool(raw['completed']),
          ),
        );
      }
      out.sort((a, b) => a.setIndex.compareTo(b.setIndex));
      for (var i = 0; i < out.length; i++) {
        out[i] = out[i].copyWith(setIndex: i + 1);
      }
    }
    if (out.isNotEmpty) return out;
    return List.generate(
      widget.sets,
      (i) => _LauncherSetRow(
        setIndex: i + 1,
        reps: widget.reps,
        rir: widget.rir,
        weightKg: 0,
        done: false,
      ),
    );
  }

  Future<void> _persistUpsert(_LauncherSetRow row) async {
    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      await TrainingNetworkResilience.withTimeout(
        TrainingService.upsertExerciseSet(
          programExerciseId: programExerciseId,
          setIndex: row.setIndex,
          reps: row.reps,
          rir: row.rir,
          weightKg: row.weightKg,
          completed: row.done,
        ),
        TrainingNetworkResilience.sheetMutation,
      );
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetUpsert,
        programExerciseId: programExerciseId,
        data: {
          "set_index": row.setIndex,
          "reps": row.reps,
          "rir": row.rir,
          "weight_kg": row.weightKg,
          "completed": row.done,
        },
      );
    }
  }

  Future<void> _addSet() async {
    final last = _rows.isEmpty ? null : _rows.last;
    final next = _LauncherSetRow(
      setIndex: _rows.length + 1,
      reps: last?.reps ?? widget.reps,
      rir: last?.rir ?? widget.rir,
      weightKg: last?.weightKg ?? 0,
      done: false,
    );
    if (mounted) {
      setState(() => _rows = [..._rows, next]);
    }
    await _saveLauncherProgressState();
    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      await TrainingNetworkResilience.withTimeout(
        TrainingService.addExerciseSet(
          programExerciseId: programExerciseId,
          cloneLast: true,
        ),
        TrainingNetworkResilience.sheetMutation,
      );
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetAdd,
        programExerciseId: programExerciseId,
        data: {"clone_last": true},
      );
    }
  }

  Future<void> _toggleDone(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final row = _rows[index].copyWith(done: !_rows[index].done);
    final next = List<_LauncherSetRow>.from(_rows);
    next[index] = row;
    if (mounted) {
      setState(() => _rows = next);
    }
    await _persistUpsert(row);
    await _saveLauncherProgressState();
  }

  Future<void> _editSetRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    final current = _rows[index];
    final result = await showTaqaSetRowEditDialog(
      context: context,
      setIndex: current.setIndex,
      reps: current.reps,
      rir: current.rir,
      weightKg: current.weightKg,
      completed: current.done,
    );
    if (result == null) return;

    final next = List<_LauncherSetRow>.from(_rows);
    final updated = current.copyWith(
      reps: result.reps,
      rir: result.rir,
      weightKg: result.weightKg,
      done: result.completed,
    );
    next[index] = updated;
    if (mounted) {
      setState(() => _rows = next);
    }
    await _persistUpsert(updated);
    await _saveLauncherProgressState();
  }

  Future<void> _deleteSetRow(int index) async {
    if (index < 0 || index >= _rows.length) return;
    if (_rows.length <= 1) return;

    final deleted = _rows[index];
    final remaining = List<_LauncherSetRow>.from(_rows)..removeAt(index);
    final reindexed = <_LauncherSetRow>[];
    for (var i = 0; i < remaining.length; i++) {
      reindexed.add(remaining[i].copyWith(setIndex: i + 1));
    }

    var nextFlowSetIndex = _flowSetIndex;
    var nextSetInProgress = _setInProgress;
    int? nextSetStartedAtMs = _setStartedAtMs;
    if (index < _flowSetIndex) {
      nextFlowSetIndex = _flowSetIndex - 1;
    } else if (index == _flowSetIndex) {
      nextSetInProgress = false;
      nextSetStartedAtMs = null;
      if (index >= reindexed.length) {
        nextFlowSetIndex = reindexed.length - 1;
      } else {
        nextFlowSetIndex = index;
      }
    }
    if (nextFlowSetIndex < 0) nextFlowSetIndex = 0;
    if (reindexed.isNotEmpty && nextFlowSetIndex >= reindexed.length) {
      nextFlowSetIndex = reindexed.length - 1;
    }

    if (mounted) {
      setState(() {
        _rows = reindexed;
        _flowSetIndex = nextFlowSetIndex;
        _setInProgress = nextSetInProgress;
        _setStartedAtMs = nextSetStartedAtMs;
      });
    }
    await _saveLauncherProgressState();

    final programExerciseId = _programExerciseId();
    if (programExerciseId == null) return;
    try {
      await TrainingNetworkResilience.withTimeout(
        TrainingService.deleteExerciseSet(
          programExerciseId: programExerciseId,
          setIndex: deleted.setIndex,
        ),
        TrainingNetworkResilience.sheetMutation,
      );
    } catch (_) {
      await ExerciseActionQueue.queueAction(
        action: ExerciseActionQueue.actionSetDelete,
        programExerciseId: programExerciseId,
        data: {"set_index": deleted.setIndex},
      );
    }
  }

  Future<void> _startExercise() async {
    if (_starting) return;
    final startSets = _rows.isEmpty ? widget.sets : _rows.length;
    final startReps = _rows.isEmpty
        ? widget.reps
        : _rows.firstWhere((r) => r.reps > 0, orElse: () => _rows.first).reps;
    final now = DateTime.now().millisecondsSinceEpoch;
    _exerciseStartedAtMs = now;
    _setStartedAtMs = now;
    _restCountdownActive = false;
    _restRemainingSeconds = 0;
    _flowSetIndex = _initialFlowSetIndex();
    _setInProgress = true;
    _exerciseFinished = false;
    _ensureActiveTimers();
    setState(() => _starting = true);
    widget.onStarted();
    try {
      await widget.onStart(
        sets: startSets <= 0 ? 1 : startSets,
        reps: startReps <= 0 ? 1 : startReps,
      );
      await _saveLauncherProgressState();
    } catch (_) {
      widget.onFinished();
      final programExerciseId = _programExerciseId();
      if (programExerciseId != null) {
        await TrainingProgressStorage.clearExerciseTimerState(
          programExerciseId,
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _showExerciseActionsSheet() async {
    final media = MediaQuery.of(context);
    final lift = (media.size.height * 0.012).clamp(6.0, 12.0).toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFF404040),
            child: Padding(
              padding: EdgeInsets.only(bottom: lift),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Material(
                  color: const Color(0xFF404040),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      10,
                      22,
                      14 + media.viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 64,
                          child: Divider(
                            thickness: 4,
                            color: Color(0x991C1D17),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TaqaSheetActionButton(
                          label: "HOW TO",
                          filled: true,
                          onTap: () async {
                            Navigator.of(context).pop();
                            final instructions =
                                (widget.exercise['instructions'] ?? '')
                                    .toString()
                                    .trim();
                            if (instructions.isEmpty) {
                              AppToast.show(
                                context,
                                "No instructions available.",
                                type: AppToastType.info,
                              );
                              return;
                            }
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ExerciseInstructionDialog(
                                  title: widget.name,
                                  instructions: instructions,
                                  animationUrl: widget.exercise['animation_url']
                                      ?.toString(),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TaqaSheetActionButton(
                          label: "REPLACE EXERCISE",
                          filled: true,
                          onTap: () {
                            Navigator.of(context).pop();
                            if (widget.isActive) {
                              AppToast.show(
                                context,
                                "Finish the current exercise before replacing it.",
                                type: AppToastType.info,
                              );
                              return;
                            }
                            widget.onReplace();
                          },
                        ),
                      ],
                    ),
                  ),
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
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final imageUrl = TrainingService.animationImageUrl(
      widget.exercise['animation_url']?.toString(),
      null,
    );
    final imageProvider = imageUrl.isEmpty
        ? null
        : TrainingService.gifProvider(
            imageUrl,
            cacheWidth: (126 * dpr).round(),
            cacheHeight: (126 * dpr).round(),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF414345),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 126,
                  height: 126,
                  color: const Color(0xFFE3E3E3),
                  child: imageProvider == null
                      ? const Icon(
                          Icons.fitness_center,
                          size: 28,
                          color: Color(0x661C1D17),
                        )
                      : Image(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 41),
                            padding: const EdgeInsets.only(top: 1, bottom: 4),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.isDone && !widget.isActive)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2ECC71),
                            size: 18,
                          )
                        else
                          GestureDetector(
                            onTap: () => unawaited(_showExerciseActionsSheet()),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      "SUGGESTED",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _suggestedTag("${_rows.length} x ${widget.reps}"),
                        const SizedBox(width: 8),
                        _suggestedTag("RIR ${widget.rir}"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: _restCountdownActive ? null : _changeRestSeconds,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: _restCountdownActive
                          ? const Color(0x88DDE530)
                          : const Color(0xFFDDE530),
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Rest: ${_restCountdownActive ? _restRemainingSeconds : _restSeconds}s",
                      style: TextStyle(
                        color: _restCountdownActive
                            ? const Color(0x88DDE530)
                            : const Color(0xFFDDE530),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      color: _restCountdownActive
                          ? const Color(0x88DDE530)
                          : const Color(0xFFDDE530),
                      size: 16,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.isActive)
                Text(
                  "Total: ${_formatMmSs(_elapsedSecondsSince(_exerciseStartedAtMs))}",
                  style: const TextStyle(
                    color: Color(0xFFDDE530),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.isActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0x22E4E93B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x55E4E93B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _setActionLabel(),
                    style: const TextStyle(
                      color: Color(0xFFE4E93B),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "SET TIMER: ${_formatMmSs(_setInProgress ? _elapsedSecondsSince(_setStartedAtMs) : 0)}",
                    style: const TextStyle(
                      color: Color(0xFFE4E93B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_restCountdownActive && !_setInProgress)
                          ? null
                          : () => unawaited(_onSetActionPressed()),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFE4E93B),
                        foregroundColor: const Color(0xFF1C1D17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        _setActionLabel(),
                        style: const TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_restCountdownActive && !_setInProgress) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _skipRestCountdown,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE4E93B),
                          side: const BorderSide(color: Color(0x55E4E93B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          "SKIP REST",
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _tableHeader(),
          const SizedBox(height: 6),
          for (int i = 0; i < _rows.length; i++) ...[
            _setRow(i),
            if (i != _rows.length - 1) const SizedBox(height: 2),
          ],
          const SizedBox(height: 10),
          _ghostButton(label: "ADD SET", onTap: _addSet),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_starting || _finishingExercise)
                  ? null
                  : (widget.isActive ? _finishExercise : _startExercise),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: TaqaUiColors.white,
                foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: TaqaUiColors.white, width: 1),
                ),
              ),
              child: (_starting || _finishingExercise)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isActive ? "FINISH EXERCISE" : "START EXERCISE",
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestedTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _tableHeader() {
    return const Row(
      children: [
        Expanded(flex: 2, child: _HeaderText("SET")),
        Expanded(flex: 3, child: _HeaderText("PREVIOUS")),
        Expanded(flex: 2, child: _HeaderText("KG")),
        Expanded(flex: 2, child: _HeaderText("REPS")),
        Expanded(flex: 2, child: _HeaderText("RIR")),
        Expanded(flex: 2, child: _HeaderText("DONE")),
        SizedBox(width: 26),
      ],
    );
  }

  Widget _setRow(int index) {
    final row = _rows[index];
    final highlightFirst = widget.isActive && index == _activeFlowSetIndex();
    final rowTextColor = highlightFirst
        ? TaqaUiColors.unnamedColor1c1d17
        : Colors.white;
    final previousColor = highlightFirst
        ? TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.8)
        : Colors.white70;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_editSetRow(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: highlightFirst ? TaqaUiColors.unnamedColorE4e93b : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                "${row.setIndex}",
                style: TextStyle(color: rowTextColor, fontSize: 18),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "-",
                style: TextStyle(color: previousColor, fontSize: 18),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                row.weightKg <= 0 ? "0" : row.weightKg.toStringAsFixed(0),
                style: TextStyle(color: rowTextColor, fontSize: 18),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "${row.reps}",
                style: TextStyle(color: rowTextColor, fontSize: 18),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "${row.rir}",
                style: TextStyle(color: rowTextColor, fontSize: 18),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => unawaited(_toggleDone(index)),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: highlightFirst
                            ? TaqaUiColors.unnamedColor1c1d17
                            : const Color(0xFFDDE530),
                      ),
                    ),
                    child: row.done
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: highlightFirst
                                ? TaqaUiColors.unnamedColor1c1d17
                                : const Color(0xFFDDE530),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 26,
              child: _rows.length > 1
                  ? GestureDetector(
                      onTap: () => unawaited(_deleteSetRow(index)),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: highlightFirst
                              ? TaqaUiColors.unnamedColor1c1d17
                              : Colors.white70,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ghostButton({required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WorkoutFloatingTimerBar extends StatelessWidget {
  const _WorkoutFloatingTimerBar({
    required this.timeText,
    required this.finishing,
  });

  final String timeText;
  final bool finishing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1C1D17).withValues(alpha: 0.14),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Color(0xFF1C1D17), size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Workout",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  Text(
                    timeText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ],
              ),
              if (finishing) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherSetRow {
  const _LauncherSetRow({
    required this.setIndex,
    required this.reps,
    required this.rir,
    required this.weightKg,
    required this.done,
  });

  final int setIndex;
  final int reps;
  final int rir;
  final double weightKg;
  final bool done;

  _LauncherSetRow copyWith({
    int? setIndex,
    int? reps,
    int? rir,
    double? weightKg,
    bool? done,
  }) {
    return _LauncherSetRow(
      setIndex: setIndex ?? this.setIndex,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      weightKg: weightKg ?? this.weightKg,
      done: done ?? this.done,
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _DayOrderResult {
  const _DayOrderResult({required this.order, required this.completedByIndex});

  final List<int> order;
  final List<bool> completedByIndex;
}

class TrainPageState extends State<TrainPage> with WidgetsBindingObserver {
  Map<String, dynamic>? program;
  int selectedDay = 0;
  bool loading = true;
  bool isOffline = false;
  Set<String> completedExerciseNames = {};
  int _tabIndex = 0; // 0 = Train, 1 = Cardio
  bool _cardioBuilt = false;
  List<Map<String, dynamic>> _cardioLibrary = const [];
  bool _loadingCardioLibrary = false;
  List<Map<String, dynamic>> _trainExercises = const [];
  final Set<String> _preloadedThumbs = <String>{};
  List<int> _dayOrder = const [];
  List<bool> _dayCompletedByIndex = const [];
  bool _isDeactivated = false;
  final Set<int> _inProgressExerciseIds = <int>{};
  // Per-exercise session start time (ms since epoch) for in-progress exercises,
  // used to show a live elapsed timer on the Resume button.
  final Map<int, int> _inProgressStartMsById = <int, int>{};
  String? _activeSessionExerciseName;
  int _inProgressLoadSeq = 0;
  Set<String> _finishedDayKeysForWeek = <String>{};
  Set<String> _sessionCompletedExerciseNames = <String>{};
  String? _activeWeekToken;
  bool _weekRefreshInProgress = false;
  Set<String> _historyWorkedDayTokensForWeek = <String>{};
  Map<String, Set<String>> _historyCompletedExerciseNamesByDayTokenForWeek =
      <String, Set<String>>{};
  String? _historyWorkedWeekToken;
  bool _historyWorkedLoadedForWeek = false;
  int _unseenPlanChangeCount = 0;
  bool _resumeRefreshInFlight = false;
  bool _hasCardioSession = false;
  bool _cardioSessionPaused = false;
  String? _sessionExerciseName;

  int? _userId;
  int? _pendingCompletionDayIndex;

  int? _workoutStartMs;
  int? _workoutDayIndex;
  int _workoutElapsedSeconds = 0;
  Timer? _workoutTimer;
  bool _finishingWorkout = false;

  // Resume flow for a workout session the server still has open but the local
  // timer lost (e.g. app force-killed mid-workout).
  static const int _staleSessionSeconds = 4 * 60 * 60; // 4 hours
  Map<String, dynamic>? _resumableSession;
  bool _openSessionCheckDone = false;
  bool _discardingResumableSession = false;

  int _exRestPresetSeconds = 60;
  int _exRestRemaining = 0;
  bool _exRestActive = false;
  bool _showExRestPanel = false;
  Timer? _exRestTimer;

  static const List<Map<String, dynamic>> _fallbackCardioLibrary = [
    {
      "exercise_id": 4154,
      "exercise_name": "Outdoor Run",
      "animation_name": "Cardio - Running",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4155,
      "exercise_name": "Treadmill",
      "animation_name": "Cardio - Treadmill",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4153,
      "exercise_name": "Rowing Machine",
      "animation_name": "Cardio - Rowing Machine",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4152,
      "exercise_name": "Jump Rope",
      "animation_name": "Cardio - Jump Rope",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountStorage.trainingChange.addListener(_onTrainingChanged);
    AccountStorage.accountChange.addListener(_onAccountChanged);
    _loadCardioLibraryFromCache();
    _init();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _exRestTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AccountStorage.trainingChange.removeListener(_onTrainingChanged);
    AccountStorage.accountChange.removeListener(_onAccountChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (_resumeRefreshInFlight) return;
    _resumeRefreshInFlight = true;
    unawaited(_refreshOnResume());
  }

  Future<void> _refreshOnResume() async {
    try {
      await TrainingResetCoordinator.ensureInitialized();
      await _refreshLightTrainState();
    } finally {
      _resumeRefreshInFlight = false;
    }
  }

  Future<void> _refreshLightTrainState() async {
    await _loadWorkoutTimer();
    await _refreshTrainingPlanChangeState();
    await _refreshAccountStatus();
  }

  void _onTrainingChanged() {
    _loadWorkoutTimer();
  }

  void _onAccountChanged() {
    _refreshAccountStatus();
  }

  Future<void> _init() async {
    await TrainingResetCoordinator.ensureInitialized();
    _userId = await AccountStorage.getUserId();
    await _loadProgram();
    await _loadWorkoutTimer();
    await _refreshAccountStatus();
    await _loadExRestPreset();
    await _restoreExRestState();
    await _refreshTrainingPlanChangeState();
    await _checkOpenWorkoutSessionOnLaunch();
  }

  /// Issues 3 & 5: reconcile the server's open workout session with local state
  /// on launch. Stale sessions (>=4h) are auto-closed silently; a recent open
  /// session the local timer lost surfaces a "Resume Workout" banner.
  Future<void> _checkOpenWorkoutSessionOnLaunch() async {
    if (_openSessionCheckDone) return;
    _openSessionCheckDone = true;

    Map<String, dynamic> session;
    try {
      session = await TrainingService.fetchCurrentSession();
    } catch (_) {
      return; // offline or schema missing — nothing to reconcile
    }
    if (!mounted) return;
    if (session.isEmpty || session['started_at'] == null) return;

    final startedAt = _parseDateTime(session['started_at']);
    if (startedAt == null) return;
    final ageSeconds = DateTime.now().difference(startedAt).inSeconds;

    // Stale (>=4h) → close silently without prompting (Issue 5).
    if (ageSeconds >= _staleSessionSeconds) {
      try {
        await TrainingService.finishStaleSessions(
          olderThanSeconds: _staleSessionSeconds,
        );
        await TrainingProgressStorage.clearWorkoutStart();
        await TrainingProgressStorage.clearAllExerciseTimers();
      } catch (_) {}
      if (!mounted) return;
      await _loadWorkoutTimer();
      return;
    }

    // Recent session the local timer already tracks — normal UI covers it.
    if (_workoutStartMs != null) return;

    // Recent open session with no local timer state (force-killed): offer
    // resume or discard (Issue 3).
    if (!mounted) return;
    setState(() => _resumableSession = session);
  }

  Future<void> _resumeWorkoutSession() async {
    final session = _resumableSession;
    if (session == null) return;
    final startedAt = _parseDateTime(session['started_at']);
    setState(() => _resumableSession = null);
    if (startedAt != null) {
      await TrainingProgressStorage.recordWorkoutStartAt(
        startMs: startedAt.millisecondsSinceEpoch,
      );
      AccountStorage.notifyTrainingChanged();
    }
    if (!mounted) return;
    await _loadWorkoutTimer();
  }

  Future<void> _discardResumableSession() async {
    if (_discardingResumableSession) return;
    if (_resumableSession == null) return;
    setState(() => _discardingResumableSession = true);
    try {
      await TrainingService.finishSession(entryDate: DateTime.now());
    } catch (_) {
      try {
        await TrainingService.finishStaleSessions(olderThanSeconds: 0);
      } catch (_) {}
    }
    try {
      await TrainingActivityService.stopSession();
      await TrainingProgressStorage.clearWorkoutStart();
      await TrainingProgressStorage.clearAllExerciseTimers();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _resumableSession = null;
      _discardingResumableSession = false;
      _activeSessionExerciseName = null;
      _inProgressExerciseIds.clear();
    });
    await _loadWorkoutTimer();
    AccountStorage.notifyTrainingChanged();
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

  Future<void> _loadCardioLibraryFromCache() async {
    final cached = await CardioExercisesStorage.loadList();
    if (!mounted || cached == null || cached.isEmpty) return;
    setState(() => _cardioLibrary = cached);
  }

  Future<void> _loadCardioLibrary() async {
    if (_loadingCardioLibrary) return;
    if (_cardioLibrary.isNotEmpty) return;
    setState(() => _loadingCardioLibrary = true);
    try {
      final items = await TrainingService.fetchCardioExercises();
      if (!mounted) return;
      final merged = items.isNotEmpty
          ? items
          : List<Map<String, dynamic>>.from(_fallbackCardioLibrary);
      setState(() {
        _cardioLibrary = merged;
        _loadingCardioLibrary = false;
      });
      CardioExercisesStorage.saveList(merged);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cardioLibrary = List<Map<String, dynamic>>.from(
          _fallbackCardioLibrary,
        );
        _loadingCardioLibrary = false;
      });
    }
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
    await _syncCardioSessionState();
  }

  bool _isCardioSession(Map<String, dynamic>? session) {
    if (session == null) return false;
    final distance = session['distanceKm'];
    final pace = session['paceMinKm'];
    return distance is num || pace is num;
  }

  String _normalizeName(String? name) {
    return (name ?? '').trim().toLowerCase();
  }

  bool _isKnownCardioExerciseName(String? rawName) {
    final target = _normalizeName(rawName);
    if (target.isEmpty) return false;
    final days = program?['days'];
    final plannedCardio = days is List
        ? _allCardioExercisesForProgram(days)
        : const <Map<String, dynamic>>[];
    final cardioList = plannedCardio.isNotEmpty
        ? plannedCardio
        : (_cardioLibrary.isNotEmpty ? _cardioLibrary : _fallbackCardioLibrary);
    for (final ex in cardioList) {
      final exName = _normalizeName(ex['exercise_name']?.toString());
      if (exName == target) return true;
    }
    return false;
  }

  Future<void> _syncCardioSessionState() async {
    final session = await TrainingActivityService.getActiveSession();
    final rawName = session?['name']?.toString();
    final isCardio =
        _isCardioSession(session) || _isKnownCardioExerciseName(rawName);
    final hasCardioSession = session != null && isCardio;
    final paused = hasCardioSession && session['paused'] == true;
    final resolvedName = hasCardioSession ? rawName : null;
    if (!mounted) return;
    setState(() {
      _hasCardioSession = hasCardioSession;
      _cardioSessionPaused = paused;
      _sessionExerciseName = resolvedName;
    });
  }

  void _continueCardioSession(List<Map<String, dynamic>> list) {
    final targetName = _normalizeName(_sessionExerciseName);
    if (targetName.isEmpty) {
      AppToast.show(
        context,
        "Couldn't find the cardio session.",
        type: AppToastType.info,
      );
      return;
    }
    Map<String, dynamic>? match;
    for (final ex in list) {
      final name = _normalizeName(ex['exercise_name']?.toString());
      if (name == targetName) {
        match = ex;
        break;
      }
    }
    if (match == null) {
      AppToast.show(
        context,
        "Paused cardio not found. Cancel to start a new one.",
        type: AppToastType.info,
      );
      return;
    }
    unawaited(_openCardioExerciseSession(match));
  }

  Future<void> _cancelPausedCardioSession() async {
    await TrainingActivityService.stopSession();
    if (!mounted) return;
    setState(() {
      _hasCardioSession = false;
      _cardioSessionPaused = false;
      _sessionExerciseName = null;
      _inProgressExerciseIds.clear();
      _activeSessionExerciseName = null;
    });
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
        await TrainingNetworkResilience.withTimeout(
          TrainingService.finishSession(entryDate: now),
          TrainingNetworkResilience.sheetMutation,
        );
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
        await healthSyncService
            .writeWorkoutSession(
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
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Ignore health write failures and continue local finish flow.
      }
    }
    await _refreshProgramForCompletionCheck().timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
    final shouldShowDayCompletePopup = hasCompletedExerciseInSession
        ? _isDayFullyCompletedForCurrentWeek(finishedDayIndex)
        : false;
    await TrainingProgressStorage.clearWorkoutStart();
    if (hasCompletedExerciseInSession) {
      final resetNow = TrainingResetCoordinator.currentNowUtc();
      await TrainingProgressStorage.recordTrainingDayCompleted(resetNow);
      if (shouldShowDayCompletePopup) {
        await _markDayFinishedForCurrentWeek(finishedDayIndex);
      } else {
        await _clearDayFinishedForCurrentWeek(finishedDayIndex);
      }
    }
    _workoutTimer?.cancel();
    _workoutTimer = null;
    _workoutStartMs = null;
    _workoutDayIndex = null;
    _workoutElapsedSeconds = 0;
    _stopExRestCountdownQuiet();
    final days = program?['days'];
    _DayOrderResult? orderResult = days is List ? _buildDayOrder(days) : null;
    _pendingCompletionDayIndex =
        hasCompletedExerciseInSession && shouldShowDayCompletePopup
        ? finishedDayIndex
        : null;
    if (mounted) {
      setState(() {
        _finishingWorkout = false;
        _showExRestPanel = false;
        _sessionCompletedExerciseNames = <String>{};
        if (orderResult != null) {
          _dayOrder = orderResult.order;
          _dayCompletedByIndex = orderResult.completedByIndex;
          if (days is List) {
            selectedDay = _firstDayInOrder(orderResult, days.length);
          }
          _rebuildExerciseLists();
        }
      });
      final shouldShowWorkoutFinishedToast =
          showToast &&
          (!hasCompletedExerciseInSession || !shouldShowDayCompletePopup);
      if (shouldShowWorkoutFinishedToast) {
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
    if (hasCompletedExerciseInSession) {
      AccountStorage.notifyTrainingChanged();
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

  /// Rebuild day order after [_loadHistoryWorkedDaysForCurrentWeek] finished
  /// (e.g. in parallel with program fetch). Does not change [selectedDay].
  Future<void> _rebuildTrainPageAfterHistoryLoaded() async {
    if (!mounted || program == null) return;
    final days = program!['days'];
    if (days is! List) return;
    try {
      await _reconcileFinishedDaysWithProgram(days);
    } catch (_) {}
    if (!mounted) return;
    final orderResult = _buildDayOrder(days);
    if (!mounted) return;
    setState(() {
      _dayOrder = orderResult.order;
      _dayCompletedByIndex = orderResult.completedByIndex;
      _rebuildExerciseLists();
    });
  }

  Future<void> _loadProgram() async {
    bool showedCache = false;
    var localCompleted = _sessionCompletedExerciseNames;
    Future<void>? historyFuture;
    try {
      await TrainingResetCoordinator.ensureInitialized();
      final userId = _userId ?? await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");
      _userId = userId;
      final activeWorkoutStartMs =
          await TrainingProgressStorage.getWorkoutStartMs();
      final localCompletedNames = activeWorkoutStartMs == null
          ? const <String>[]
          : await TrainingProgressStorage.getSessionCompletedExerciseNamesSince(
              activeWorkoutStartMs,
            );
      localCompleted = localCompletedNames
          .map(_normalizeExerciseName)
          .where((e) => e.isNotEmpty)
          .toSet();
      await _loadFinishedDaysForCurrentWeek();
      // Run in parallel with cache + network refresh so we never block the
      // cached-program paint on this request.
      historyFuture = _loadHistoryWorkedDaysForCurrentWeek(
        force: true,
        allowRemote: false,
      );

      // Show cached program immediately if available (no blank UI), except
      // right after a regeneration where cache may still be the old plan.
      if (program == null && !TrainingRegenerationFlag.isRegenerating) {
        try {
          final cached = await TrainingService.fetchActiveProgramFromCache();
          if (cached != null && mounted) {
            final cachedDays = cached['days'];
            final cachedDayCount = cachedDays is List ? cachedDays.length : 0;
            if (cachedDays is List) {
              await _reconcileFinishedDaysWithProgram(cachedDays);
            }
            final orderResult = cachedDays is List
                ? _buildDayOrder(cachedDays)
                : const _DayOrderResult(order: [], completedByIndex: []);
            setState(() {
              program = cached;
              loading = false;
              isOffline = false;
              _sessionCompletedExerciseNames = localCompleted;
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
        await TrainingNetworkResilience.withTimeout(
          ExerciseActionQueue.syncQueue(),
          TrainingNetworkResilience.actionQueueSync,
        );
      } catch (_) {
        // Ignore sync errors, continue loading program
      }

      // Try to fetch from server first
      final data = await TrainingNetworkResilience.withTimeout(
        TrainingService.fetchActiveProgram(userId),
        TrainingNetworkResilience.programFetch,
      );
      Set<String> completed = {};
      try {
        final names = await TrainingNetworkResilience.withTimeout(
          TrainingService.fetchCompletedExerciseNames(userId),
          TrainingNetworkResilience.completedNamesFetch,
        );
        completed = names
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      } catch (_) {
        // Ignore completed names fetch errors
      }
      if (!mounted) return;
      try {
        if (historyFuture != null) {
          await historyFuture;
        }
      } catch (_) {}
      if (!mounted) return;
      final serverDays = data['days'];
      final serverDayCount = serverDays is List ? serverDays.length : 0;
      if (serverDays is List) {
        await _reconcileFinishedDaysWithProgram(serverDays);
      }
      final orderResult = serverDays is List
          ? _buildDayOrder(serverDays)
          : const _DayOrderResult(order: [], completedByIndex: []);
      setState(() {
        program = data;
        loading = false;
        isOffline = false;
        completedExerciseNames = completed;
        _sessionCompletedExerciseNames = localCompleted;
        _dayOrder = orderResult.order;
        _dayCompletedByIndex = orderResult.completedByIndex;
        selectedDay = _firstDayInOrder(orderResult, serverDayCount);
        _rebuildExerciseLists();
      });
      TrainingRegenerationFlag.clear();
      _preloadExerciseGifsForCurrentDay();
      await _refreshInProgressExercises();
      await _maybeShowDayCompletedPopup();
      unawaited(_refreshTrainingPlanChangeState());
      return;
    } catch (_) {
      if (historyFuture != null) {
        unawaited(
          historyFuture!.then((_) => _rebuildTrainPageAfterHistoryLoaded()),
        );
      }
      if (!mounted) return;
      if (program != null || showedCache) {
        setState(() {
          loading = false;
          isOffline = true;
          _sessionCompletedExerciseNames = localCompleted;
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
          _sessionCompletedExerciseNames = localCompleted;
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
      return;
    }
    final days = data['days'];
    if (days is! List || days.isEmpty) {
      _trainExercises = const [];
      return;
    }
    if (selectedDay >= days.length) {
      selectedDay = 0;
    }
    final currentDay = days[selectedDay];
    final exercises = currentDay is Map ? currentDay['exercises'] : null;
    final List<Map<String, dynamic>> train = [];
    if (exercises is List) {
      for (final ex in exercises) {
        if (ex is Map<String, dynamic>) {
          if (!_isCardioExercise(ex)) {
            train.add(ex);
          }
        }
      }
    }
    _trainExercises = train;
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
    final startMsById = <int, int>{};

    for (final ex in exercises) {
      final id = _programExerciseId(ex);
      if (id == null) continue;
      final state = await TrainingProgressStorage.loadExerciseTimerState(id);
      if (state == null) continue;
      if (state['started'] == true) {
        inProgressIds.add(id);
        final startMs = state['start_ms'];
        if (startMs is int && startMs > 0) {
          startMsById[id] = startMs;
        } else if (startMs is num && startMs > 0) {
          startMsById[id] = startMs.toInt();
        }
      }
    }

    if (!mounted || seq != _inProgressLoadSeq) return;
    final changed =
        inProgressIds.length != _inProgressExerciseIds.length ||
        !inProgressIds.containsAll(_inProgressExerciseIds);
    // The start-ms map can change even when the id set doesn't, but we only
    // need a rebuild when membership changes; the 1s ticker re-renders timers.
    if (!changed) {
      _inProgressStartMsById
        ..clear()
        ..addAll(startMsById);
      return;
    }
    setState(() {
      _inProgressExerciseIds
        ..clear()
        ..addAll(inProgressIds);
      _inProgressStartMsById
        ..clear()
        ..addAll(startMsById);
    });
  }

  _DayOrderResult _buildDayOrder(List days) {
    if (days.isEmpty) {
      return const _DayOrderResult(order: [], completedByIndex: []);
    }
    final now = TrainingResetCoordinator.currentNowUtc();
    final weekStart = _weekStartMonday(now);
    _activeWeekToken = _dateToken(weekStart);
    final weekEnd = _weekEndSunday(now);
    final completedByIndex = List<bool>.filled(days.length, false);
    final greenByIndex = List<bool>.filled(days.length, false);
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is Map<String, dynamic>) {
        final isDone = _isDayAnyExerciseCompletedFromHistory(day, i);
        completedByIndex[i] = isDone;
        greenByIndex[i] = isDone;
      } else if (day is Map) {
        final dayMap = Map<String, dynamic>.from(day);
        final isDone = _isDayAnyExerciseCompletedFromHistory(dayMap, i);
        completedByIndex[i] = isDone;
        greenByIndex[i] = isDone;
      }
    }
    // Keep current week "green" days (worked or complete) at the end.
    final order = _orderByCompletionFlags(greenByIndex);
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

  Future<void> _startExerciseFromLauncher(
    Map<String, dynamic> ex, {
    required int sets,
    required int reps,
  }) async {
    _stopExRestCountdownQuiet();
    if (mounted) setState(() {});

    final days = program?['days'];
    Map<String, dynamic> exerciseWithDay = ex;
    final rawDayIndex = ex['training_day_index'];
    final resolvedDayIndex = rawDayIndex is int
        ? rawDayIndex
        : (rawDayIndex is num
                  ? rawDayIndex.toInt()
                  : int.tryParse(rawDayIndex?.toString() ?? '')) ??
              selectedDay;
    if (days is List &&
        resolvedDayIndex >= 0 &&
        resolvedDayIndex < days.length) {
      final day = days[resolvedDayIndex];
      if (day is Map) {
        exerciseWithDay = Map<String, dynamic>.from(ex);
        exerciseWithDay['training_day_id'] = day['day_id'];
        exerciseWithDay['training_day_label'] = day['day_label'];
        exerciseWithDay['training_day_index'] = resolvedDayIndex;
      }
    }

    final now = DateTime.now();
    final entryDateToken =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final programExerciseId = _programExerciseId(exerciseWithDay);
    if (programExerciseId != null) {
      try {
        await TrainingNetworkResilience.withTimeout(
          TrainingService.startExercise(programExerciseId, entryDate: now),
          TrainingNetworkResilience.sheetMutation,
        );
      } catch (_) {
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionStart,
          programExerciseId: programExerciseId,
          data: {"entry_date": entryDateToken},
        );
      }
    }

    _markExerciseInProgress(exerciseWithDay);
    if (!_isCardioExercise(exerciseWithDay)) {
      await TrainingProgressStorage.recordWorkoutStart(
        trainingDayIndex: resolvedDayIndex,
      );
      AccountStorage.notifyTrainingChanged();
    }

    final name = (exerciseWithDay['exercise_name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      await TrainingActivityService.startSession(
        exerciseName: name,
        sets: sets <= 0 ? 1 : sets,
        reps: reps <= 0 ? 1 : reps,
        seconds: 0,
      );
    }

    if (!mounted) return;
    await _loadWorkoutTimer();
    await _refreshInProgressExercises();
  }

  Future<void> _handleExerciseFinishedFromLauncher(
    Map<String, dynamic> ex,
  ) async {
    final programExerciseId = _programExerciseId(ex);
    final normalizedName = _normalizeExerciseName(ex['exercise_name']);
    if (mounted) {
      setState(() {
        if (programExerciseId != null) {
          _inProgressExerciseIds.remove(programExerciseId);
        }
        if (normalizedName.isNotEmpty) {
          _sessionCompletedExerciseNames = <String>{
            ..._sessionCompletedExerciseNames,
            normalizedName,
          };
        }
        _activeSessionExerciseName = null;
        _showExRestPanel = true;
      });
      if (!_exRestActive) {
        _startExRestCountdown();
      }
    }
    await _loadWorkoutTimer();
    await _refreshInProgressExercises();
    await _refreshDoneExercisesFromHistory();
  }

  Future<void> _openCardioExerciseSession(Map<String, dynamic> ex) async {
    _stopExRestCountdownQuiet();
    if (mounted) setState(() {});

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thumbW = (86 * dpr).round();
    final thumbH = (78 * dpr).round();
    final sheetH = (200 * dpr).round();
    final gifUrl = TrainingService.animationImageUrl(
      resolvedCardioAnimationUrl(
        ex['exercise_name']?.toString(),
        ex['animation_url']?.toString(),
      ),
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
      TrainingService.warmGif(
        context,
        gifUrl,
        cacheHeight: sheetH,
      ).catchError((_) {});
    }

    final days = program?['days'];
    Map<String, dynamic> exerciseWithDay = ex;
    final rawDayIndex = ex['training_day_index'];
    final resolvedDayIndex = rawDayIndex is int
        ? rawDayIndex
        : (rawDayIndex is num
                  ? rawDayIndex.toInt()
                  : int.tryParse(rawDayIndex?.toString() ?? '')) ??
              selectedDay;
    if (days is List &&
        resolvedDayIndex >= 0 &&
        resolvedDayIndex < days.length) {
      final day = days[resolvedDayIndex];
      if (day is Map) {
        exerciseWithDay = Map<String, dynamic>.from(ex);
        exerciseWithDay['training_day_id'] = day['day_id'];
        exerciseWithDay['training_day_label'] = day['day_label'];
        exerciseWithDay['training_day_index'] = resolvedDayIndex;
      }
    }

    final useFullscreenIndoorCardio = isIndoorCardioExerciseName(
      exerciseWithDay['exercise_name']?.toString(),
    );
    if (useFullscreenIndoorCardio) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ExerciseSessionSheet(
            exercise: exerciseWithDay,
            completedExerciseNames: completedExerciseNames,
            onFinished: () {
              if (_tabIndex == 0 && mounted) {
                setState(() {
                  _showExRestPanel = true;
                });
                if (!_exRestActive) {
                  _startExRestCountdown();
                }
              }
              unawaited(_loadProgram());
              _loadWorkoutTimer();
            },
            onStarted: () => _markExerciseInProgress(exerciseWithDay),
            onAllSetsCompleted: () =>
                _markExerciseLocallyCompleted(exerciseWithDay),
            previewProvider: previewProvider,
            showSessionOnOpen: true,
            useFullscreenLayout: true,
          ),
        ),
      );
    } else {
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
                });
                if (!_exRestActive) {
                  _startExRestCountdown();
                }
              }
              unawaited(_loadProgram());
              _loadWorkoutTimer();
            },
            onStarted: () => _markExerciseInProgress(exerciseWithDay),
            onAllSetsCompleted: () =>
                _markExerciseLocallyCompleted(exerciseWithDay),
            previewProvider: previewProvider,
            showSessionOnOpen: true,
          ),
        ),
      );
    }
    if (!mounted) return;
    await _loadWorkoutTimer();
    await _refreshInProgressExercises();
  }

  // Optimistically mark an exercise completed in local state so its card turns
  // green immediately (before the next server refresh). Does not run finish-
  // session side effects; that still happens via onFinished.
  void _markExerciseLocallyCompleted(Map<String, dynamic> ex) {
    final normalizedName = _normalizeExerciseName(ex['exercise_name']);
    if (normalizedName.isEmpty || !mounted) return;
    if (_sessionCompletedExerciseNames.contains(normalizedName)) return;
    setState(() {
      _sessionCompletedExerciseNames = <String>{
        ..._sessionCompletedExerciseNames,
        normalizedName,
      };
    });
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
    unawaited(_loadCardioLibrary());
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

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 4 && word == word.toUpperCase()) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

  List<Map<String, dynamic>> _trainingExercisesForDay({
    required List days,
    required int dayIndex,
    required String dayLabel,
  }) {
    if (dayIndex < 0 || dayIndex >= days.length) return const [];
    final day = days[dayIndex];
    final exercises = day is Map ? day['exercises'] : null;
    if (exercises is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final rawEx in exercises) {
      Map<String, dynamic>? ex;
      if (rawEx is Map<String, dynamic>) {
        ex = Map<String, dynamic>.from(rawEx);
      } else if (rawEx is Map) {
        ex = Map<String, dynamic>.from(rawEx);
      }
      if (ex == null || _isCardioExercise(ex)) continue;
      ex['training_day_index'] = dayIndex;
      ex['training_day_label'] = dayLabel;
      if (day is Map) {
        ex['training_day_id'] = day['day_id'];
      }
      out.add(ex);
    }
    return out;
  }

  List<Map<String, dynamic>> _allCardioExercisesForProgram(List days) {
    final out = <Map<String, dynamic>>[];
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final exercises = day is Map ? day['exercises'] : null;
      if (exercises is! List) continue;
      final dayLabel =
          (day is Map
                  ? (day['day_label'] ?? day['label'] ?? 'Day ${dayIndex + 1}')
                  : 'Day ${dayIndex + 1}')
              .toString();
      for (final rawEx in exercises) {
        Map<String, dynamic>? ex;
        if (rawEx is Map<String, dynamic>) {
          ex = Map<String, dynamic>.from(rawEx);
        } else if (rawEx is Map) {
          ex = Map<String, dynamic>.from(rawEx);
        }
        if (ex == null || !_isCardioExercise(ex)) continue;
        ex['training_day_index'] = dayIndex;
        ex['training_day_label'] = dayLabel;
        if (day is Map) {
          ex['training_day_id'] = day['day_id'];
        }
        out.add(ex);
      }
    }
    return out;
  }

  // Public entry used by the app-shell minimized workout bar: open the
  // in-progress day's exercises page (same destination as START WORKOUT).
  Future<void> openActiveWorkoutLauncher() async {
    final days = program?['days'];
    if (days is! List || days.isEmpty) return;
    int dayIndex = _workoutDayIndex ??
        (selectedDay >= 0 && selectedDay < days.length ? selectedDay : 0);
    if (dayIndex < 0 || dayIndex >= days.length) dayIndex = 0;
    final day = days[dayIndex];
    final dayLabel =
        (day is Map
                ? (day['day_label'] ?? day['label'] ?? 'Day ${dayIndex + 1}')
                : 'Day ${dayIndex + 1}')
            .toString();
    await _openTrainingDayExercisesPage(
      days: days,
      dayIndex: dayIndex,
      dayLabel: dayLabel,
    );
  }

  Future<void> _openTrainingDayExercisesPage({
    required List days,
    required int dayIndex,
    required String dayLabel,
  }) async {
    setState(() {
      selectedDay = dayIndex;
      _rebuildExerciseLists();
    });
    await _preloadExerciseGifsForCurrentDay();
    await _refreshInProgressExercises();

    if (!mounted) return;
    final exercises = _trainingExercisesForDay(
      days: days,
      dayIndex: dayIndex,
      dayLabel: dayLabel,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrainingDayExercisesPage(
          dayLabel: dayLabel,
          exercises: exercises,
          readDisabledState: () => _isDayDisabledForWorkout(dayIndex),
          readDayNoteState: () => _dayNoteForWorkoutLock(dayIndex),
          readLiveState: _readTrainingDayLiveState,
          readHistoryCompletedExerciseNames: () {
            final day = _dayAtIndex(dayIndex);
            if (day == null) return const <String>{};
            return _historyCompletedExerciseNamesForDay(day, dayIndex);
          },
          programExerciseIdOf: _programExerciseId,
          normalizeExerciseName: _normalizeExerciseName,
          onStartExercise: _startExerciseFromLauncher,
          onExerciseFinished: _handleExerciseFinishedFromLauncher,
          onReplaceExercise: _openReplaceSheet,
          onWorkoutSessionClosed: () async {
            await _loadWorkoutTimer();
            await _refreshInProgressExercises();
          },
          onFinishWorkout: () => _finishWorkout(),
          onSkipRest: _skipExRest,
          onStartRest: _startExRestCountdown,
          onSetCustomRest: _setCustomExRestPreset,
          restPresets: const [10, 15, 30, 45, 60],
          onSelectRestPreset: _setExRestPreset,
        ),
      ),
    );
    if (!mounted) return;
    await _loadWorkoutTimer();
    await _refreshInProgressExercises();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshDoneExercisesFromHistory() async {
    await _loadHistoryWorkedDaysForCurrentWeek(force: true);
    final days = program?['days'];
    if (days is! List) return;
    try {
      await _reconcileFinishedDaysWithProgram(days);
    } catch (_) {}
    if (!mounted) return;
    final orderResult = _buildDayOrder(days);
    if (!mounted) return;
    setState(() {
      _dayOrder = orderResult.order;
      _dayCompletedByIndex = orderResult.completedByIndex;
      _rebuildExerciseLists();
    });
  }

  bool _isDayDisabledForWorkout(int dayIndex) {
    if (_isDeactivated) return true;
    final workoutLockDayIndex =
        (_workoutStartMs != null && _workoutDayIndex != null)
        ? _workoutDayIndex
        : null;
    if (workoutLockDayIndex == null) return false;
    return dayIndex != workoutLockDayIndex;
  }

  String? _dayNoteForWorkoutLock(int dayIndex) {
    if (_isDeactivated) return "Account is deactivated";
    final workoutLockDayIndex =
        (_workoutStartMs != null && _workoutDayIndex != null)
        ? _workoutDayIndex
        : null;
    if (workoutLockDayIndex == null || dayIndex == workoutLockDayIndex) {
      return null;
    }
    return "Workout in progress";
  }

  Widget _buildResumeWorkoutBanner() {
    final startedAt = _parseDateTime(_resumableSession?['started_at']);
    final elapsed = startedAt == null
        ? null
        : _formatWorkoutTime(DateTime.now().difference(startedAt).inSeconds);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1C1D17).withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill, color: Color(0xFF1C1D17), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Workout in progress",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                Text(
                  elapsed != null
                      ? "Started $elapsed ago — resume or discard"
                      : "Resume or discard your last session",
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _discardingResumableSession
                ? null
                : () => unawaited(_discardResumableSession()),
            style: TextButton.styleFrom(
              foregroundColor: TaqaUiColors.unnamedColor1c1d17,
            ),
            child: _discardingResumableSession
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Discard"),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _discardingResumableSession
                ? null
                : () => unawaited(_resumeWorkoutSession()),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFE4E93B),
              foregroundColor: const Color(0xFF1C1D17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Resume",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  _TrainingDayLiveState _readTrainingDayLiveState() {
    return _TrainingDayLiveState(
      inProgressExerciseIds: Set<int>.from(_inProgressExerciseIds),
      inProgressStartMsById: Map<int, int>.from(_inProgressStartMsById),
      activeSessionExerciseName: _activeSessionExerciseName,
      sessionCompletedExerciseNames: Set<String>.from(
        _sessionCompletedExerciseNames,
      ),
      showWorkoutTimer: _workoutStartMs != null,
      workoutTimeText: _formatWorkoutTime(_workoutElapsedSeconds),
      finishingWorkout: _finishingWorkout,
      showRestPanel: _showExRestPanel || _exRestActive,
      restActive: _exRestActive,
      restTimeText: _exRestActive
          ? _formatRestTime(_exRestRemaining)
          : "Rest ${_formatRestTime(_exRestPresetSeconds)}",
      activeRestPreset: _exRestPresetSeconds,
    );
  }

  bool _isCardioExercise(Map<String, dynamic> ex) {
    String? _str(dynamic v) => v == null ? null : v.toString().toLowerCase();

    final animationName = _str(ex['animation_name']) ?? '';
    // Trust explicit cardio tag in animation_name (e.g., "Cardio - ...")
    return animationName.startsWith('cardio -');
  }

  DateTime _weekStartMonday(DateTime d) {
    return TrainingResetCoordinator.weekStartMonday(d);
  }

  DateTime _weekEndSunday(DateTime d) {
    return TrainingResetCoordinator.weekEndSunday(d);
  }

  String _dateToken(DateTime d) {
    return TrainingResetCoordinator.dateToken(d);
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

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  String _normalizeDayIdentity(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  Set<String> _programDayIdentityTokens(Map<String, dynamic> day, int index) {
    final tokens = <String>{'index:${index + 1}'};
    final dayId = _parseInt(
      day['day_id'] ?? day['training_day_id'] ?? day['id'],
    );
    if (dayId != null && dayId > 0) {
      tokens.add('id:$dayId');
    }

    final dayKey = _normalizeDayIdentity(day['day_key']);
    if (dayKey.isNotEmpty) {
      tokens.add('key:$dayKey');
      tokens.add('label:$dayKey');
    }

    final labels = [day['day_label'], day['label'], day['day_name']];
    for (final label in labels) {
      final normalized = _normalizeDayIdentity(label);
      if (normalized.isEmpty) continue;
      tokens.add('label:$normalized');
      tokens.add('key:$normalized');
    }
    return tokens;
  }

  Set<String> _historyDayIdentityTokens(Map<String, dynamic> item) {
    final tokens = <String>{};
    final dayId = _parseInt(
      item['training_day_id'] ?? item['day_id'] ?? item['id'],
    );
    if (dayId != null && dayId > 0) {
      tokens.add('id:$dayId');
    }

    final dayIndex = _parseInt(
      item['day_index'] ?? item['day_number'] ?? item['day_no'] ?? item['day'],
    );
    if (dayIndex != null && dayIndex > 0) {
      tokens.add('index:$dayIndex');
    }

    final keys = [item['day_key'], item['dayKey']];
    for (final key in keys) {
      final normalized = _normalizeDayIdentity(key);
      if (normalized.isEmpty) continue;
      tokens.add('key:$normalized');
      tokens.add('label:$normalized');
    }

    final labels = [item['label'], item['day_label'], item['day_name']];
    for (final label in labels) {
      final normalized = _normalizeDayIdentity(label);
      if (normalized.isEmpty) continue;
      tokens.add('label:$normalized');
      tokens.add('key:$normalized');
    }
    return tokens;
  }

  Set<String> _historyCompletedExerciseNames(Map<String, dynamic> item) {
    final names = <String>{};
    void addName(dynamic value) {
      final normalized = _normalizeExerciseName(value);
      if (normalized.isNotEmpty) names.add(normalized);
    }

    final completedExercises = item['completed_exercises'];
    if (completedExercises is List) {
      for (final entry in completedExercises) {
        if (entry is String) {
          addName(entry);
        } else if (entry is Map) {
          addName(
            entry['exercise_name'] ??
                entry['name'] ??
                entry['title'] ??
                entry['exercise'],
          );
        }
      }
    }
    return names;
  }

  bool _historyRowHasWorkedState(Map<String, dynamic> item) {
    if (_flagTrue(item['is_completed_day'])) return true;
    if (_flagTrue(item['worked']) || _flagTrue(item['has_progress'])) {
      return true;
    }

    final completedCount = _parseInt(item['completed_count']) ?? 0;
    if (completedCount > 0) return true;

    final completedExercises = item['completed_exercises'];
    if (completedExercises is List && completedExercises.isNotEmpty) {
      return true;
    }

    final status = (item['status_text'] ?? item['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status.isEmpty) return false;
    return status.contains('progress') ||
        status.contains('complete') ||
        status.contains('done') ||
        status.contains('finish');
  }

  bool _historyRowInCurrentWeek(
    Map<String, dynamic> item,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final explicitWeekStart = _parseDateTime(item['week_start']);
    if (explicitWeekStart != null) {
      return _dateToken(_weekStartMonday(explicitWeekStart)) ==
          _dateToken(weekStart);
    }

    final rowDate = _parseDateTime(
      item['latest_date'] ??
          item['entry_date'] ??
          item['logged_at'] ??
          item['completed_at'] ??
          item['performed_at'],
    );
    if (rowDate == null) return false;
    return _isInWeek(rowDate, weekStart, weekEnd);
  }

  Future<void> _loadHistoryWorkedDaysForCurrentWeek({
    bool force = false,
    bool allowRemote = true,
  }) async {
    final weekStart = _weekStartMonday(
      TrainingResetCoordinator.currentNowUtc(),
    );
    final weekEnd = _weekEndSunday(weekStart);
    final weekToken = _dateToken(weekStart);
    if (!force &&
        _historyWorkedLoadedForWeek &&
        _historyWorkedWeekToken == weekToken) {
      return;
    }

    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) {
      _historyWorkedDayTokensForWeek = <String>{};
      _historyCompletedExerciseNamesByDayTokenForWeek = <String, Set<String>>{};
      _historyWorkedWeekToken = weekToken;
      _historyWorkedLoadedForWeek = false;
      return;
    }

    try {
      final cachedHistory = await TrainingService.readCachedTrainingHistory(
        userId: userId,
        minLimitDays: 42,
      );
      if (cachedHistory == null && !allowRemote) {
        _historyWorkedDayTokensForWeek = <String>{};
        _historyCompletedExerciseNamesByDayTokenForWeek =
            <String, Set<String>>{};
        _historyWorkedWeekToken = weekToken;
        _historyWorkedLoadedForWeek = false;
        return;
      }
      final history =
          cachedHistory ??
          (allowRemote
              ? await TrainingService.fetchTrainingHistory(
                  userId: userId,
                  limitDays: 42,
                )
              : const <Map<String, dynamic>>[]);
      final workedTokens = <String>{};
      final completedByDayToken = <String, Set<String>>{};
      for (final row in history) {
        if (!_historyRowInCurrentWeek(row, weekStart, weekEnd)) continue;
        if (!_historyRowHasWorkedState(row)) continue;
        final rowTokens = _historyDayIdentityTokens(row);
        final rowNames = _historyCompletedExerciseNames(row);
        if (rowTokens.isNotEmpty && rowNames.isNotEmpty) {
          for (final token in rowTokens) {
            completedByDayToken
                .putIfAbsent(token, () => <String>{})
                .addAll(rowNames);
          }
        }
        workedTokens.addAll(rowTokens);
      }
      _historyWorkedDayTokensForWeek = workedTokens;
      _historyCompletedExerciseNamesByDayTokenForWeek = completedByDayToken;
      _historyWorkedWeekToken = weekToken;
      _historyWorkedLoadedForWeek = true;
    } catch (_) {
      _historyWorkedDayTokensForWeek = <String>{};
      _historyCompletedExerciseNamesByDayTokenForWeek = <String, Set<String>>{};
      _historyWorkedWeekToken = weekToken;
      _historyWorkedLoadedForWeek = false;
    }
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
    return TrainingResetCoordinator.isInWeek(
      date,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
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
            compliance['performed_at'] ??
            compliance['entry_date'],
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
      ex['performed_at'],
      ex['entry_date'],
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
    if (_isDayFlaggedCompletedForWeek(day, weekStart, weekEnd)) return true;
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
    DateTime weekEnd, {
    int? dayIndex,
  }) {
    final weekToken = _dateToken(weekStart);
    if (!_historyWorkedLoadedForWeek || _historyWorkedWeekToken != weekToken) {
      return false;
    }
    if (dayIndex == null || dayIndex < 0) return false;
    final tokens = _programDayIdentityTokens(day, dayIndex);
    return tokens.any(_historyWorkedDayTokensForWeek.contains);
  }

  Set<String> _historyCompletedExerciseNamesForDay(
    Map<String, dynamic> day,
    int dayIndex,
  ) {
    if (!_historyWorkedLoadedForWeek || dayIndex < 0) return const <String>{};
    final tokens = _programDayIdentityTokens(day, dayIndex);
    if (tokens.isEmpty) return const <String>{};
    final names = <String>{};
    for (final token in tokens) {
      final tokenNames = _historyCompletedExerciseNamesByDayTokenForWeek[token];
      if (tokenNames == null || tokenNames.isEmpty) continue;
      names.addAll(tokenNames);
    }
    return names;
  }

  bool _isDayAnyExerciseCompletedFromHistory(
    Map<String, dynamic> day,
    int dayIndex,
  ) {
    return _historyCompletedExerciseNamesForDay(day, dayIndex).isNotEmpty;
  }

  bool _isDayAnyExerciseCompletedForWeek(
    Map<String, dynamic> day, {
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    for (final rawEx in exercises) {
      Map<String, dynamic>? ex;
      if (rawEx is Map<String, dynamic>) {
        ex = rawEx;
      } else if (rawEx is Map) {
        ex = Map<String, dynamic>.from(rawEx);
      }
      if (ex == null) continue;
      if (_isCardioExercise(ex)) continue;
      if (_isExerciseCompletedForWeek(ex, weekStart, weekEnd)) {
        return true;
      }
    }
    return false;
  }

  bool _isDayAnyExerciseCompletedLocally(Map<String, dynamic> day) {
    if (_sessionCompletedExerciseNames.isEmpty) return false;
    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    for (final rawEx in exercises) {
      Map<String, dynamic>? ex;
      if (rawEx is Map<String, dynamic>) {
        ex = rawEx;
      } else if (rawEx is Map) {
        ex = Map<String, dynamic>.from(rawEx);
      }
      if (ex == null) continue;
      if (_isCardioExercise(ex)) continue;
      final name = _normalizeExerciseName(ex['exercise_name']);
      if (name.isNotEmpty && _sessionCompletedExerciseNames.contains(name)) {
        return true;
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
      await _loadHistoryWorkedDaysForCurrentWeek(force: true);
      final data = await TrainingService.fetchActiveProgram(userId);
      final serverDays = data['days'];
      final serverDayCount = serverDays is List ? serverDays.length : 0;
      if (serverDays is List) {
        await _reconcileFinishedDaysWithProgram(serverDays);
      }
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

  bool _isDayFullyCompletedForCurrentWeek(int dayIndex) {
    final day = _dayAtIndex(dayIndex);
    if (day == null) return false;
    final now = TrainingResetCoordinator.currentNowUtc();
    return _isDayFullyCompletedForWeek(
      day,
      weekStart: _weekStartMonday(now),
      weekEnd: _weekEndSunday(now),
    );
  }

  bool _isDayFullyCompletedForWeek(
    Map<String, dynamic> day, {
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
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
      final completed = _isExerciseCompletedForWeek(ex, weekStart, weekEnd);
      if (!completed) return false;
    }
    return hasTrainExercise;
  }

  DateTime? _dayCompletionDate(Map<String, dynamic> day) {
    final candidates = [
      day['logged_at'],
      day['completed_at'],
      day['performed_at'],
      day['entry_date'],
      day['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isDayFlaggedCompletedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final flags = [
      day['is_completed'],
      day['completed'],
      day['program_compliance_completed'],
    ];
    if (!flags.any(_flagTrue)) return false;
    final completionDate = _dayCompletionDate(day);
    if (completionDate == null) return false;
    return _isInWeek(completionDate, weekStart, weekEnd);
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
    final weekToken = await TrainingResetCoordinator.currentWeekStartToken();
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
    final weekStart = _weekStartMonday(
      TrainingResetCoordinator.currentNowUtc(),
    );
    final dayKey = _dayCompletionKey(day, dayIndex, weekStart);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_finishedDayStorageKey(userId, dayKey), true);
    _finishedDayKeysForWeek = {..._finishedDayKeysForWeek, dayKey};
  }

  Future<void> _reconcileFinishedDaysWithProgram(List days) async {
    if (days.isEmpty || _finishedDayKeysForWeek.isEmpty) return;
    final now = TrainingResetCoordinator.currentNowUtc();
    final weekStart = _weekStartMonday(now);
    final weekEnd = _weekEndSunday(now);
    final staleDayKeys = <String>{};
    for (var i = 0; i < days.length; i++) {
      final rawDay = days[i];
      Map<String, dynamic>? day;
      if (rawDay is Map<String, dynamic>) {
        day = rawDay;
      } else if (rawDay is Map) {
        day = Map<String, dynamic>.from(rawDay);
      }
      if (day == null) continue;
      final dayKey = _dayCompletionKey(day, i, weekStart);
      if (!_finishedDayKeysForWeek.contains(dayKey)) continue;
      final isActuallyComplete = _isDayFullyCompletedForWeek(
        day,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
      if (!isActuallyComplete) {
        staleDayKeys.add(dayKey);
      }
    }
    if (staleDayKeys.isEmpty) return;
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    for (final dayKey in staleDayKeys) {
      await sp.remove(_finishedDayStorageKey(userId, dayKey));
      await sp.remove("train_day_completed_popup_u${userId}_$dayKey");
    }
    _finishedDayKeysForWeek = _finishedDayKeysForWeek
        .where((key) => !staleDayKeys.contains(key))
        .toSet();
  }

  Future<void> _clearDayFinishedForCurrentWeek(int dayIndex) async {
    final day = _dayAtIndex(dayIndex);
    if (day == null) return;
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final weekStart = _weekStartMonday(
      TrainingResetCoordinator.currentNowUtc(),
    );
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

    final now = TrainingResetCoordinator.currentNowUtc();
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
      barrierColor: const Color(0x66000000),
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingDayCompleteSheet(dayLabel: label),
    );
  }

  void _scheduleWeekRefreshIfNeeded() {
    if (_weekRefreshInProgress || program == null) return;
    final currentWeekToken = _dateToken(
      _weekStartMonday(TrainingResetCoordinator.currentNowUtc()),
    );
    if (_activeWeekToken == currentWeekToken) return;
    _activeWeekToken = currentWeekToken;
    unawaited(_refreshWeekScopedUiState());
  }

  Future<void> _refreshWeekScopedUiState() async {
    if (_weekRefreshInProgress) return;
    _weekRefreshInProgress = true;
    try {
      await _loadFinishedDaysForCurrentWeek();
      await _loadHistoryWorkedDaysForCurrentWeek(force: true);
      final data = program;
      if (data == null) return;
      final days = data['days'];
      if (days is! List) return;
      await _reconcileFinishedDaysWithProgram(days);
      final orderResult = _buildDayOrder(days);
      if (!mounted) return;
      setState(() {
        _dayOrder = orderResult.order;
        _dayCompletedByIndex = orderResult.completedByIndex;
        selectedDay = _firstDayInOrder(orderResult, days.length);
        _rebuildExerciseLists();
      });
    } finally {
      _weekRefreshInProgress = false;
    }
  }

  Future<void> _refreshTrainingPlanChangeState() async {
    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null || userId <= 0) return;
    try {
      final payload = await TrainingService.fetchTrainingPlanChanges(
        userId: userId,
        markSeen: false,
      );
      final unseen = payload['unseen_count'] is int
          ? payload['unseen_count'] as int
          : 0;
      if (!mounted) return;
      setState(() {
        _unseenPlanChangeCount = unseen;
      });
    } catch (_) {
      // Keep page responsive if log fetch fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (loading && program == null) {
      return _buildLoadingSkeleton(context);
    }

    if (program == null) {
      return Center(
        child: Text(
          t.translate("no_active_training_program"),
          style: const TextStyle(color: TaqaUiColors.unnamedColor1c1d17),
        ),
      );
    }

    _scheduleWeekRefreshIfNeeded();

    final List days = program!['days'] ?? [];
    final dayOrder = _effectiveDayOrder(days);
    final completedInOrder = dayOrder
        .map(
          (i) => (i >= 0 && i < _dayCompletedByIndex.length)
              ? _dayCompletedByIndex[i]
              : false,
        )
        .toList();
    final nowForWorked = TrainingResetCoordinator.currentNowUtc();
    final weekStartForWorked = _weekStartMonday(nowForWorked);
    final weekEndForWorked = _weekEndSunday(nowForWorked);
    final workedInOrder = dayOrder.map((i) {
      if (i < 0 || i >= days.length) return false;
      final rawDay = days[i];
      Map<String, dynamic>? day;
      if (rawDay is Map<String, dynamic>) {
        day = rawDay;
      } else if (rawDay is Map) {
        day = Map<String, dynamic>.from(rawDay);
      }
      if (day == null) return false;
      return _isDayWorkedForWeek(
        day,
        weekStartForWorked,
        weekEndForWorked,
        dayIndex: i,
      );
    }).toList();
    final workoutLockDayIndex =
        (_workoutStartMs != null && _workoutDayIndex != null)
        ? _workoutDayIndex
        : null;
    final notesInOrder = List<String?>.generate(dayOrder.length, (i) {
      if (_isDeactivated) return "Account is deactivated";
      if (workoutLockDayIndex == null) return null;
      final actualDayIndex = dayOrder[i];
      if (actualDayIndex == workoutLockDayIndex) return null;
      return "Workout in progress";
    });

    if (days.isEmpty) {
      return Center(
        child: Text(
          t.translate("no_active_training_program"),
          style: const TextStyle(color: TaqaUiColors.unnamedColor1c1d17),
        ),
      );
    }

    if (selectedDay >= days.length) {
      selectedDay = 0;
    }

    return Container(
      color: TaqaUiColors.unnamedColorE3e3e3,
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
                        style: TextStyle(
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  if (_resumableSession != null) _buildResumeWorkoutBanner(),
                  Center(
                    child: Text(
                      _titleCase(t.translate("training")),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 2.5,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TaqaRangeTab(
                          label: "Train",
                          selected: _tabIndex == 0,
                          onTap: _openTrainTab,
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(15)),
                      Expanded(
                        child: TaqaRangeTab(
                          label: "Cardio",
                          selected: _tabIndex == 1,
                          onTap: _openCardioTab,
                        ),
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
                    backgroundColor: Colors.white,
                    onRefresh: _refreshLightTrainState,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Workout List",
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(25),
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                            TaqaTagButton(
                              onTap: () async {
                                final currentProgram = program;
                                if (currentProgram == null) return;
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TrainingHistoryPage(
                                      program: currentProgram,
                                      initialTabIndex:
                                          _unseenPlanChangeCount > 0 ? 1 : 0,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                await _refreshTrainingPlanChangeState();
                              },
                              icon: Icons.history,
                              label: _unseenPlanChangeCount > 0
                                  ? "HISTORY ${_unseenPlanChangeCount}"
                                  : "HISTORY",
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(5)),
                        Text(
                          "Follow the sets & reps shown for each exercise",
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w400,
                            height: 18 / 15,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(30)),
                        ...dayOrder.asMap().entries.map((entry) {
                          final displayIndex = entry.key;
                          final dayIndex = entry.value;
                          final rawDay = days[dayIndex];
                          Map<String, dynamic>? dayMap;
                          if (rawDay is Map<String, dynamic>) {
                            dayMap = rawDay;
                          } else if (rawDay is Map) {
                            dayMap = Map<String, dynamic>.from(rawDay);
                          }
                          final dayLabel =
                              (dayMap?['day_label'] ??
                                      dayMap?['label'] ??
                                      'Day ${dayIndex + 1}')
                                  .toString();
                          final dayNote = displayIndex < notesInOrder.length
                              ? notesInOrder[displayIndex]
                              : null;
                          final isCompleted =
                              displayIndex < completedInOrder.length
                              ? completedInOrder[displayIndex]
                              : false;
                          final isWorked = displayIndex < workedInOrder.length
                              ? workedInOrder[displayIndex]
                              : false;
                          final dayExercises = _trainingExercisesForDay(
                            days: days,
                            dayIndex: dayIndex,
                            dayLabel: dayLabel,
                          );
                          final exerciseNames = dayExercises
                              .map(
                                (ex) => _titleCase(
                                  (ex['exercise_name'] ?? '').toString().trim(),
                                ),
                              )
                              .where((name) => name.isNotEmpty)
                              .toList();
                          final exercisePreview = exerciseNames.isEmpty
                              ? "No Exercises"
                              : exerciseNames.join(", ");

                          final isWorkoutLockDay =
                              workoutLockDayIndex != null &&
                              dayIndex == workoutLockDayIndex;
                          final isLockedOut =
                              workoutLockDayIndex != null &&
                              dayIndex != workoutLockDayIndex;

                          return Padding(
                            padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                            child: Opacity(
                              opacity: isLockedOut ? 0.5 : 1,
                              child: InkWell(
                                borderRadius: TaqaUiScale.radius(15),
                                onTap: () {
                                  if (isLockedOut) {
                                    AppToast.show(
                                      context,
                                      "Finish your in-progress workout before viewing other days.",
                                      type: AppToastType.info,
                                    );
                                    return;
                                  }
                                  unawaited(
                                    _openTrainingDayExercisesPage(
                                      days: days,
                                      dayIndex: dayIndex,
                                      dayLabel: dayLabel,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: TaqaUiScale.insetsLTRB(
                                    14,
                                    10,
                                    14,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: TaqaUiScale.radius(15),
                                    border: Border.all(
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withOpacity(0.1),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _titleCase(dayLabel),
                                              style: TextStyle(
                                                fontFamily: TaqaUiFontFamilies
                                                    .interTight,
                                                fontSize: TaqaUiScale.sp(15),
                                                fontWeight: FontWeight.w700,
                                                height: 25 / 15,
                                                letterSpacing: 0,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17,
                                              ),
                                            ),
                                            SizedBox(height: TaqaUiScale.h(19)),
                                            Text(
                                              exercisePreview,
                                              style: TextStyle(
                                                fontFamily: TaqaUiFontFamilies
                                                    .interTight,
                                                fontSize: TaqaUiScale.sp(15),
                                                fontWeight: FontWeight.w400,
                                                height: 21 / 15,
                                                letterSpacing: 0,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17,
                                              ),
                                            ),
                                            if (dayNote != null &&
                                                dayNote.trim().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  dayNote,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: TaqaUiColors
                                                            .unnamedColor1c1d17
                                                            .withOpacity(0.6),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isCompleted || isWorked)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Color(0xFF2ECC71),
                                          ),
                                        )
                                      else if (isWorkoutLockDay)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.play_circle_fill,
                                                  size: 12,
                                                  color: Color(0xFF2ECC71),
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  "CONTINUE",
                                                  style: TextStyle(
                                                    fontFamily:
                                                        TaqaUiFontFamilies
                                                            .interTight,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: TaqaUiColors.unnamedColor1c1d17
                                            .withOpacity(0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: Colors.white,
                    onRefresh: _refreshLightTrainState,
                    child: _cardioBuilt
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Cardio List",
                                      style: const TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                        color: TaqaUiColors.unnamedColor1c1d17,
                                      ),
                                    ),
                                  ),
                                  TaqaTagButton(
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CardioHistoryPage(),
                                        ),
                                      );
                                    },
                                    icon: Icons.history,
                                    label: "HISTORY",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Follow the plan shown for each cardio exercise",
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...(() {
                                final plannedCardio =
                                    _allCardioExercisesForProgram(days);
                                final cardioExercises = plannedCardio.isNotEmpty
                                    ? plannedCardio
                                    : (_cardioLibrary.isNotEmpty
                                          ? _cardioLibrary
                                          : _fallbackCardioLibrary);
                                final widgets = <Widget>[];
                                if (_hasCardioSession) {
                                  widgets.add(
                                    CardioResumeBanner(
                                      paused: _cardioSessionPaused,
                                      exerciseName: _sessionExerciseName,
                                      onContinue: () => _continueCardioSession(
                                        cardioExercises,
                                      ),
                                      onCancel: () => unawaited(
                                        _cancelPausedCardioSession(),
                                      ),
                                    ),
                                  );
                                }
                                if (cardioExercises.isEmpty) {
                                  widgets.add(
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: Text(
                                        t.translate("rest_day"),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: TaqaUiColors
                                                  .unnamedColor1c1d17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  );
                                  return widgets;
                                }
                                final workoutLockDayIndex =
                                    (_workoutStartMs != null &&
                                        _workoutDayIndex != null)
                                    ? _workoutDayIndex
                                    : null;
                                widgets.addAll(
                                  cardioExercises.asMap().entries.map((entry) {
                                    final ex = entry.value;
                                    final rawId =
                                        ex['program_exercise_id'] ??
                                        ex['exercise_id'] ??
                                        ex['exercise_name'] ??
                                        entry.key;
                                    final normalizedName =
                                        _normalizeExerciseName(
                                          ex['exercise_name'],
                                        );
                                    final locallyCompleted =
                                        normalizedName.isNotEmpty &&
                                        _sessionCompletedExerciseNames.contains(
                                          normalizedName,
                                        );
                                    final rawDayIndex =
                                        ex['training_day_index'];
                                    final dayIndex = rawDayIndex is int
                                        ? rawDayIndex
                                        : (rawDayIndex is num
                                              ? rawDayIndex.toInt()
                                              : int.tryParse(
                                                  rawDayIndex?.toString() ?? '',
                                                ));
                                    final cardDisabled =
                                        _isDeactivated ||
                                        (workoutLockDayIndex != null &&
                                            dayIndex != null &&
                                            dayIndex != workoutLockDayIndex);
                                    final exKey = ValueKey("cardio_ex_$rawId");
                                    return Padding(
                                      key: exKey,
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: ExerciseCard(
                                        exercise: ex,
                                        onTap: () {
                                          unawaited(
                                            _openCardioExerciseSession(ex),
                                          );
                                        },
                                        onReplace: () => _openReplaceSheet(ex),
                                        disabled: cardDisabled,
                                        forceCompleted: locallyCompleted,
                                        inProgress: false,
                                      ),
                                    );
                                  }).toList(),
                                );
                                return widgets;
                              })(),
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
      color: TaqaUiColors.unnamedColorE3e3e3,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate("training"),
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 2.5,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
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
                      color: Colors.white,
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
