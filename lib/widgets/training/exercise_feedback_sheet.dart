import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
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
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget body;

    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.translate("training_feedback_title"),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.translate("training_feedback_subtitle"),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...questions.map((q) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['question'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < q['options'].length; i++)
                          ChoiceChip(
                            label: Text(q['options'][i]),
                            selected: answers[q['index']] == i,
                            onSelected: (_) =>
                                setState(() => answers[q['index']] = i),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(t.translate("common_cancel")),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitFeedback,
                  child: Text(t.translate("training_feedback_submit")),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.surfaceVariant.withOpacity(0.4),
              cs.primary.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: body,
        ),
      ),
    );
  }
}
