import 'package:flutter/material.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
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
  static const double _sheetDesignHeight = 520;
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

  void _cancel() {
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
    final bottomInset = media.viewInsets.bottom + media.padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: TaqaUiScale.h(_sheetDesignHeight) + bottomInset,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(TaqaUiScale.r(15)),
              ),
              child: Material(
                color: TaqaUiColors.graphite,
                child: SingleChildScrollView(
                  padding: TaqaUiScale.insetsLTRB(17, 20, 16, 18 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: TaqaUiScale.h(3)),
                      SizedBox(
                        width: TaqaUiScale.w(168),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w700,
                            height: 25 / 15,
                            letterSpacing: 0,
                            color: TaqaUiColors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(4)),
                      SizedBox(
                        width: TaqaUiScale.w(329),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(10),
                            fontWeight: FontWeight.w400,
                            height: 18 / 10,
                            letterSpacing: 0,
                            color: TaqaUiColors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(31)),
                      if (hasQuestions)
                        Column(
                          children: questions.map((q) {
                            final index = q['index'] as int;
                            final question = q['question'] as String;
                            final options = q['options'] as List<String>;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: TaqaUiScale.h(12),
                              ),
                              child: Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  minHeight: TaqaUiScale.h(83),
                                ),
                                padding: TaqaUiScale.insetsLTRB(13, 11, 13, 11),
                                decoration: BoxDecoration(
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                  borderRadius: TaqaUiScale.radius(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      question,
                                      style: TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        fontSize: TaqaUiScale.sp(10),
                                        fontWeight: FontWeight.w700,
                                        height: 25 / 10,
                                        letterSpacing: 0,
                                        color: TaqaUiColors.white,
                                      ),
                                    ),
                                    SizedBox(height: TaqaUiScale.h(9)),
                                    Wrap(
                                      spacing: TaqaUiScale.w(8),
                                      runSpacing: TaqaUiScale.h(8),
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (int i = 0; i < options.length; i++)
                                          SizedBox(
                                            width: TaqaUiScale.w(103),
                                            height: TaqaUiScale.h(30),
                                            child: OutlinedButton(
                                              onPressed: () => setState(
                                                () => answers[index] = i,
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                side: BorderSide(
                                                  color: TaqaUiColors.white,
                                                  width: 0.5,
                                                ),
                                                backgroundColor:
                                                    answers[index] == i
                                                    ? TaqaUiColors.white
                                                    : Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      TaqaUiScale.radius(5),
                                                ),
                                              ),
                                              child: Text(
                                                options[i].toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: TaqaUiFontFamilies
                                                      .iaWriterMonoS,
                                                  fontSize: TaqaUiScale.sp(8),
                                                  fontWeight: FontWeight.w400,
                                                  height: 10 / 8,
                                                  letterSpacing: 0,
                                                  color: answers[index] == i
                                                      ? TaqaUiColors
                                                            .unnamedColor1c1d17
                                                      : TaqaUiColors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Center(
                          child: Text(
                            loading
                                ? ''
                                : (error ??
                                      t.translate("no_feedback_questions")),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(10),
                              fontWeight: FontWeight.w400,
                              height: 18 / 10,
                              letterSpacing: 0,
                              color: TaqaUiColors.white,
                            ),
                          ),
                        ),
                      SizedBox(height: TaqaUiScale.h(18)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: TaqaUiScale.w(70)),
                            child: TextButton(
                              onPressed: _cancel,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                t.translate("common_cancel").toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(10),
                                  fontWeight: FontWeight.w600,
                                  height: 12 / 10,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: TaqaUiScale.w(173),
                            height: TaqaUiScale.h(45),
                            child: ElevatedButton(
                              onPressed: hasQuestions ? _submitFeedback : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor:
                                    TaqaUiColors.unnamedColorE4e93b,
                                foregroundColor:
                                    TaqaUiColors.unnamedColor1c1d17,
                                disabledBackgroundColor: TaqaUiColors
                                    .unnamedColorE4e93b
                                    .withValues(alpha: 0.45),
                                disabledForegroundColor: TaqaUiColors
                                    .unnamedColor1c1d17
                                    .withValues(alpha: 0.65),
                                shape: RoundedRectangleBorder(
                                  borderRadius: TaqaUiScale.radius(5),
                                ),
                              ),
                              child: Text(
                                t
                                    .translate("training_feedback_submit")
                                    .toUpperCase(),
                                textAlign: TextAlign.center,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
