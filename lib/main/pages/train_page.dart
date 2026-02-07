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
        if (!mounted) return;
        setState(() {
          program = data;
          loading = false;
          isOffline = false;
        });
        return;
      } catch (e) {
        // Network failed, try loading from cache
        final cached = await TrainingService.fetchActiveProgramFromCache();
        if (cached != null) {
          if (!mounted) return;
          setState(() {
            program = cached;
            loading = false;
            isOffline = true;
          });
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

  void _startExerciseFlow(Map<String, dynamic> ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseSessionSheet(
        exercise: ex,
        onFinished: _loadProgram,
      ),
    ).whenComplete(() {
      _loadProgram();
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
              Text(
                currentDay['day_label'] ?? "",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
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
              if (exercises.isEmpty)
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
                ...exercises.map<Widget>((ex) {
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
      ),
    );
  }
}
