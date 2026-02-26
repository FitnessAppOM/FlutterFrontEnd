import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/training/day_selector.dart';
import '../../widgets/training/exercise_card.dart';
import '../../widgets/training/exercise_session_sheet.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_service.dart';
import '../../widgets/training/replace_exercise_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../screens/cardio/cardio_tab.dart';
import '../../consents/consent_manager.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  Map<String, dynamic>? program;
  int selectedDay = 0;
  bool loading = true;
  bool isOffline = false;
  Set<String> completedExerciseNames = {};
  int _tabIndex = 0; // 0 = Train, 1 = Cardio

  int? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await AccountStorage.getUserId();
    await _loadProgram();
  }

  Future<void> _loadProgram() async {
    try {
      final userId = _userId ?? await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      // Try to sync queued actions first (if online)
      try {
        await ExerciseActionQueue.syncQueue();
      } catch (_) {
        // Ignore sync errors, continue loading program
      }

      // Try to fetch from server first
      try {
        final data = await TrainingService.fetchActiveProgram(userId);
        Set<String> completed = {};
        try {
          final names = await TrainingService.fetchCompletedExerciseNames(userId);
          completed = names.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
        } catch (_) {
          // Ignore completed names fetch errors
        }
        if (!mounted) return;
        setState(() {
          program = data;
          loading = false;
          isOffline = false;
          completedExerciseNames = completed;
        });
        _preloadExerciseGifsFromProgram();
        return;
      } catch (e) {
        // Network failed, try loading from cache
        final cached = await TrainingService.fetchActiveProgramFromCache();
        if (cached != null) {
          Set<String> completed = completedExerciseNames;
          try {
            final names = await TrainingService.fetchCompletedExerciseNames(userId);
            completed = names.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
          } catch (_) {
            // Ignore completed names fetch errors
          }
          if (!mounted) return;
          setState(() {
            program = cached;
            loading = false;
            isOffline = true;
            completedExerciseNames = completed;
          });
          _preloadExerciseGifsFromProgram();
          // Show offline indicator
          if (mounted) {
            final t = AppLocalizations.of(context);
            AppToast.show(
              context,
              t.translate("offline_mode_using_cached_data") ?? "Offline: Using cached data",
              type: AppToastType.info,
            );
          }
          return;
        }
        // No cache available, rethrow original error
        rethrow;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        program = null;
        isOffline = false;
      });
    }
  }

  Future<void> _preloadExerciseGifsFromProgram() async {
    if (!mounted) return;
    final data = program;
    if (data == null) return;
    try {
      final days = data['days'];
      if (days is! List) return;
      for (final day in days) {
        final exercises = day is Map ? day['exercises'] : null;
        if (exercises is! List) continue;
        for (final ex in exercises) {
          if (!mounted) return;
          if (ex is! Map<String, dynamic>) continue;
          final url = TrainingService.animationImageUrl(
            ex['animation_url']?.toString(),
            ex['animation_rel_path']?.toString(),
          );
          if (url.isEmpty) continue;
          try {
            await precacheImage(NetworkImage(url), context);
          } catch (_) {
            // Ignore individual preload failures.
          }
        }
      }
    } catch (_) {
      // Ignore preload failures.
    }
  }

  void _startExerciseFlow(Map<String, dynamic> ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseSessionSheet(
        exercise: ex,
        completedExerciseNames: completedExerciseNames,
        onFinished: _loadProgram,
      ),
    ).whenComplete(() {
      _loadProgram();
    });
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
    setState(() => _tabIndex = 1);
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
      builder: (_) => ReplaceExerciseSheet(
        userId: userId,
        programExercise: ex,
      ),
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
          color: active ? const Color(0xFF2D7CFF) : Colors.white.withOpacity(0.05),
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

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (program == null) {
      return Center(
        child: Text(t.translate("no_active_training_program")),
      );
    }

    final List days = program!['days'] ?? [];

    if (days.isEmpty) {
      return Center(
        child: Text(t.translate("no_active_training_program")),
      );
    }

    if (selectedDay >= days.length) {
      selectedDay = 0;
    }

    final currentDay = days[selectedDay];
    final List exercises = currentDay['exercises'] ?? [];
    final List<Map<String, dynamic>> trainExercises = [];
    final List<Map<String, dynamic>> cardioExercises = [];
    for (final ex in exercises) {
      if (ex is Map<String, dynamic>) {
        if (_isCardioExercise(ex)) {
          cardioExercises.add(ex);
        } else {
          trainExercises.add(ex);
        }
      }
    }
    final List<Map<String, dynamic>> visibleExercises =
        _tabIndex == 1 ? cardioExercises : trainExercises;

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: RefreshIndicator(
          color: Colors.blueAccent,
          backgroundColor: Colors.black87,
          onRefresh: _loadProgram,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
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
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
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
              Row(
                children: [
                  _tabButton(
                    label: "Train",
                    active: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
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
              Visibility(
                visible: _tabIndex == 0,
                maintainState: true,
                maintainAnimation: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DaySelector(
                      labels: days.map<String>((d) => d['day_label'].toString()).toList(),
                      selectedIndex: selectedDay,
                      onSelect: (i) => setState(() => selectedDay = i),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.translate("training_exercise_list_title"),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.translate("training_exercise_list_sub"),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (visibleExercises.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            t.translate("rest_day"),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      ...visibleExercises.map<Widget>((ex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: ExerciseCard(
                            exercise: ex,
                            onTap: () => _startExerciseFlow(ex),
                            onReplace: () => _openReplaceSheet(ex),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              Visibility(
                visible: _tabIndex == 1,
                maintainState: true,
                maintainAnimation: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    CardioTab(
                      exercises: cardioExercises,
                      onStart: _startExerciseFlow,
                      onReplace: _openReplaceSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
