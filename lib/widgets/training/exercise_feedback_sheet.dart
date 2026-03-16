import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_service.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../widgets/app_toast.dart';
import '../../services/core/feedback_questions_storage.dart';

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
  List<Map<String, dynamic>> questions = [];
  final Map<int, int> answers = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  bool _isMeaningfulText(dynamic value) {
    if (value == null) return false;
    final text = value.toString().trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower != "nan" && lower != "null" && lower != "undefined";
  }

  List<String> _sanitizeOptions(dynamic rawOptions) {
    if (rawOptions is! List) return const [];
    final options = <String>[];
    for (final option in rawOptions) {
      if (_isMeaningfulText(option)) {
        options.add(option.toString().trim());
      }
    }
    return options;
  }

  int _safeIndex(dynamic rawIndex, int fallback) {
    if (rawIndex is int) return rawIndex;
    if (rawIndex is num) return rawIndex.toInt();
    if (rawIndex is String) return int.tryParse(rawIndex.trim()) ?? fallback;
    return fallback;
  }

  List<Map<String, dynamic>> _sanitizeQuestions(List<dynamic> rawQuestions) {
    final sanitized = <Map<String, dynamic>>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final raw = rawQuestions[i];
      if (raw is! Map) continue;
      final question = raw['question'];
      if (!_isMeaningfulText(question)) continue;
      final options = _sanitizeOptions(raw['options']);
      if (options.isEmpty) continue;
      sanitized.add({
        "index": _safeIndex(raw['index'], i),
        "question": question.toString().trim(),
        "options": options,
      });
    }
    return sanitized;
  }

  Future<void> _loadQuestions() async {
    try {
      // Try to load from server (will fallback to cache if offline)
      final q = await TrainingService.getFeedbackQuestions(
        widget.exerciseName,
      );
      final sanitized = _sanitizeQuestions(q);
      if (!mounted) return;
      setState(() {
        questions = sanitized;
        loading = false;
        error = null;
      });
    } catch (e) {
      // Try loading from cache as fallback
      try {
        final cached = await FeedbackQuestionsStorage.loadQuestions(
          widget.exerciseName,
        );
        final sanitized = _sanitizeQuestions(cached);
        if (!mounted) return;
        if (sanitized.isNotEmpty) {
          setState(() {
            questions = sanitized;
            loading = false;
            error = null;
          });
        } else {
          // No cache available
          if (!mounted) return;
          setState(() {
            loading = false;
            error = "No questions available offline";
          });
        }
      } catch (_) {
        // Both failed
        if (!mounted) return;
        setState(() {
          loading = false;
          error = "Failed to load questions";
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    final t = AppLocalizations.of(context);
    bool needsSync = false;

    for (final q in questions) {
      final index = q['index'] as int;
      final answer = answers[index];
      if (answer != null) {
        try {
          await TrainingService.submitFeedback(
            programExerciseId: widget.programExerciseId,
            questionIndex: index,
            answer: answer,
          );
        } catch (e) {
          // Queue feedback action if offline
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionFeedback,
            programExerciseId: widget.programExerciseId,
            data: {
              "question_index": index,
              "answer": answer,
            },
          );
          needsSync = true;
        }
      }
    }

    if (needsSync && mounted) {
      AppToast.show(
        context,
        t.translate("feedback_saved_offline") ?? "Feedback saved offline. Will sync when online.",
        type: AppToastType.info,
      );
    }

    widget.onDone();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget body;

    if (loading) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: cs.primary),
              const SizedBox(width: 10),
              Text(
                t.translate("training_feedback_title"),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            backgroundColor: cs.surfaceVariant.withOpacity(0.4),
            color: cs.primary,
            minHeight: 4,
          ),
          const SizedBox(height: 10),
          Text(
            t.translate("loading") ?? "Loading...",
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );
    } else if (error != null || questions.isEmpty) {
      // Show message if no questions available
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: cs.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                error ?? t.translate("no_feedback_questions") ?? "No feedback questions available",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDone();
                },
                child: Text(t.translate("common_close") ?? "Close"),
              ),
            ],
          ),
        ),
      );
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
            final index = q['index'] as int;
            final question = q['question'] as String;
            final options = q['options'] as List<String>;
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
                      question,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < options.length; i++)
                          ChoiceChip(
                            label: Text(options[i]),
                            selected: answers[index] == i,
                            onSelected: (_) =>
                                setState(() => answers[index] = i),
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
                  onPressed: () {
                    widget.onDone();
                    Navigator.of(context).maybePop();
                  },
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
