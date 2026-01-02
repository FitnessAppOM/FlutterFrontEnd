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

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionHeader(title: t.translate("training")),
          const SizedBox(height: 16),

          DaySelector(
            labels: days.map<String>((d) => d['day_label']).toList(),
            selectedIndex: selectedDay,
            onSelect: (i) => setState(() => selectedDay = i),
          ),

          const SizedBox(height: 20),

          // ✅ B) Rest day handling
          if (exercises.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  t.translate("rest_day"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          else
            ...exercises.map<Widget>((ex) {
              return ExerciseCard(
                exercise: ex,
                onTap: () {
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
                  );
                },
              );
            }).toList(),
        ],
      ),
    );
  }
}
