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
  State<ExerciseFeedbackSheet> createState() => _ExerciseFeedbackSheetState();
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
    // Render immediately using cached questions when available.
    try {
      final cached = await FeedbackQuestionsStorage.loadQuestions(
        widget.exerciseName,
      );
      final sanitizedCached = _sanitizeQuestions(cached);
      if (!mounted) return;
      if (sanitizedCached.isNotEmpty) {
        setState(() {
          questions = sanitizedCached;
          loading = false;
          error = null;
        });
      } else {
        setState(() {
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = null;
      });
    }

    try {
      final q = await TrainingService.getFeedbackQuestions(widget.exerciseName);
      final sanitized = _sanitizeQuestions(q);
      if (!mounted) return;
      setState(() {
        questions = sanitized;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
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
            data: {"question_index": index, "answer": answer},
          );
          needsSync = true;
        }
      }
    }

    if (needsSync && mounted) {
      AppToast.show(
        context,
        t.translate("feedback_saved_offline"),
        type: AppToastType.info,
      );
    }

    widget.onDone();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = _titleCase(t.translate("training_feedback_title"));
    final subtitle = t.translate("training_feedback_subtitle");
    final hasQuestions = questions.isNotEmpty;
    final media = MediaQuery.of(context);
    final bottomLift = (media.size.height * 0.018).clamp(8.0, 16.0).toDouble();
    final sheetHeight = (media.size.height * 0.5) + bottomLift;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        height: sheetHeight,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: const Color(0xFF404040),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 8 + media.viewInsets.bottom + bottomLift,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(
                      width: 64,
                      child: Divider(thickness: 4, color: Color(0x991C1D17)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'InterTight',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'InterTight',
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: hasQuestions
                        ? SingleChildScrollView(
                            child: Column(
                              children: questions.map((q) {
                                final index = q['index'] as int;
                                final question = q['question'] as String;
                                final options = q['options'] as List<String>;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF191C16),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          question,
                                          style: const TextStyle(
                                            fontFamily: 'InterTight',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            for (
                                              int i = 0;
                                              i < options.length;
                                              i++
                                            ) ...[
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => setState(
                                                    () => answers[index] = i,
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(
                                                      color: answers[index] == i
                                                          ? Colors.white
                                                          : Colors.white70,
                                                      width: 1,
                                                    ),
                                                    backgroundColor:
                                                        answers[index] == i
                                                        ? Colors.white
                                                        : Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 10,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    options[i].toUpperCase(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          'IAWriterMonoS',
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: answers[index] == i
                                                          ? const Color(
                                                              0xFF1C1D17,
                                                            )
                                                          : Colors.white,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (i != options.length - 1)
                                                const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : Center(
                            child: Text(
                              loading ? '' : (error ?? ''),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'InterTight',
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            widget.onDone();
                            Navigator.of(context).maybePop();
                          },
                          child: Text(
                            (t.translate("common_cancel")).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'InterTight',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hasQuestions ? _submitFeedback : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDDE530),
                            foregroundColor: const Color(0xFF1C1D17),
                            disabledBackgroundColor: const Color(0x66DDE530),
                            disabledForegroundColor: const Color(0x801C1D17),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            (t.translate(
                              "training_feedback_submit",
                            )).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'InterTight',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
