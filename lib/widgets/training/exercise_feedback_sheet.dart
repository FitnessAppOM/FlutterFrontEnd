import 'package:flutter/material.dart';
import '../../services/training_service.dart';

class ExerciseFeedbackSheet extends StatefulWidget {
  final int programExerciseId;
  final String exerciseName;
  final VoidCallback onDone;

  const ExerciseFeedbackSheet({
    super.key,
    required this.programExerciseId,
    required this.exerciseName,
    required this.onDone,
  });

  @override
  State<ExerciseFeedbackSheet> createState() =>
      _ExerciseFeedbackSheetState();
}

class _ExerciseFeedbackSheetState extends State<ExerciseFeedbackSheet> {
  List questions = [];
  final Map<int, int> answers = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final q = await TrainingService.getFeedbackQuestions(
      widget.exerciseName,
    );
    setState(() {
      questions = q;
      loading = false;
    });
  }

  Future<void> _submitFeedback() async {
    for (final q in questions) {
      final index = q['index'];
      final answer = answers[index];
      if (answer != null) {
        await TrainingService.submitFeedback(
          programExerciseId: widget.programExerciseId,
          questionIndex: index,
          answer: answer,
        );
      }
    }

    widget.onDone();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final q in questions) ...[
              Text(
                q['question'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < q['options'].length; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: answers[q['index']],
                  title: Text(q['options'][i]),
                  onChanged: (v) =>
                      setState(() => answers[q['index']] = v!),
                ),
              const Divider(),
            ],
            ElevatedButton(
              onPressed: _submitFeedback,
              child: const Text("Submit Feedback"),
            ),
          ],
        ),
      ),
    );
  }
}
