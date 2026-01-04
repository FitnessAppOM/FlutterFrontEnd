import 'package:flutter/material.dart';
import '../../services/training_service.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/training/day_selector.dart';
import '../../widgets/training/exercise_card.dart';
import '../../widgets/training/exercise_session_sheet.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  Map<String, dynamic>? program;
  int selectedDay = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  Future<void> _loadProgram() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      final data = await TrainingService.fetchActiveProgram(userId);

      setState(() {
        program = data;
        loading = false;
      });
    } catch (_) {
      setState(() {
        loading = false;
        program = null;
      });
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

    final List days = program!['days'];

    // ✅ A) Protect against out-of-range selected day
    if (selectedDay >= days.length) {
      selectedDay = 0;
    }

    final currentDay = days[selectedDay];
    final List exercises = currentDay['exercises'] ?? [];

    void startExerciseFlow(Map<String, dynamic> ex) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (_) => ExerciseSessionSheet(
          exercise: ex,
          onFinished: _loadProgram,
        ),
      ).whenComplete(() {
        // If the sheet is dismissed by swiping down, still refresh the program state.
        _loadProgram();
      });
    }

    Map<String, dynamic>? firstPending() {
      final pending = exercises.firstWhere(
        (e) => e['is_completed'] != true,
        orElse: () => exercises.isNotEmpty ? exercises.first : null,
      );
      if (pending is Map<String, dynamic>) return pending;
      return null;
    }

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
                labels: days.map<String>((d) => d['day_label']).toList(),
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
                      onTap: () => startExerciseFlow(ex),
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
