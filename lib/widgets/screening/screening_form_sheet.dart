import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/screenings/screening_service.dart';
import '../../TaqaUI/components/taqa_toast.dart';

/// Full-screen modal that collects 7 screening questions
/// (EQ-5D-3L + PHQ-2) and submits them.
class ScreeningFormSheet extends StatefulWidget {
  const ScreeningFormSheet({super.key, required this.pending});

  final ScreeningPendingResult pending;

  /// Show as a full-screen modal route. Returns `true` when screening was
  /// submitted successfully.
  static Future<bool?> show(
    BuildContext context,
    ScreeningPendingResult pending,
  ) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScreeningFormSheet(pending: pending),
      ),
    );
  }

  @override
  State<ScreeningFormSheet> createState() => _ScreeningFormSheetState();
}

class _ScreeningFormSheetState extends State<ScreeningFormSheet> {
  int? _mobility;
  int? _selfCare;
  int? _usualActivities;
  int? _painDiscomfort;
  int? _anxietyDepression;
  int? _q1Interest;
  int? _q2Mood;

  bool _submitting = false;

  String t(String key) => AppLocalizations.of(context).translate(key);

  bool get _allAnswered =>
      _mobility != null &&
      _selfCare != null &&
      _usualActivities != null &&
      _painDiscomfort != null &&
      _anxietyDepression != null &&
      _q1Interest != null &&
      _q2Mood != null;

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    setState(() => _submitting = true);
    try {
      await ScreeningApi.submit(
        userId: userId,
        mobility: _mobility!,
        selfCare: _selfCare!,
        usualActivities: _usualActivities!,
        painDiscomfort: _painDiscomfort!,
        anxietyDepression: _anxietyDepression!,
        q1Interest: _q1Interest!,
        q2Mood: _q2Mood!,
      );
      if (mounted) {
        AppToast.show(
          context,
          t("screening_submitted"),
          type: AppToastType.success,
        );
        Navigator.of(context).pop(true);
      }
    } on ScreeningConflictException {
      if (mounted) {
        AppToast.show(
          context,
          t("screening_already_submitted"),
          type: AppToastType.info,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          t("screening_failed").replaceAll("{error}", "$e"),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.pending.daysRemaining;

    return Scaffold(
      appBar: TaqaPageAppBar(
        title: t("screening_title"),
        leading: CloseButton(color: TaqaUiColors.unnamedColor1c1d17),
      ),
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t("screening_subtitle"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(12),
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  if (days != null) ...[
                    SizedBox(height: TaqaUiScale.h(10)),
                    _DaysRemainingChip(days: days),
                  ],
                  SizedBox(height: TaqaUiScale.h(20)),

                  // ── EQ-5D-3L ──
                  _SectionLabel(label: t("screening_eq5d_section")),
                  SizedBox(height: TaqaUiScale.h(12)),

                  _Eq5dQuestion(
                    title: t("screening_q_mobility"),
                    options: [
                      t("screening_q_mobility_1"),
                      t("screening_q_mobility_2"),
                      t("screening_q_mobility_3"),
                    ],
                    value: _mobility,
                    onChanged: (v) => setState(() => _mobility = v),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _Eq5dQuestion(
                    title: t("screening_q_self_care"),
                    options: [
                      t("screening_q_self_care_1"),
                      t("screening_q_self_care_2"),
                      t("screening_q_self_care_3"),
                    ],
                    value: _selfCare,
                    onChanged: (v) => setState(() => _selfCare = v),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _Eq5dQuestion(
                    title: t("screening_q_usual_activities"),
                    options: [
                      t("screening_q_usual_activities_1"),
                      t("screening_q_usual_activities_2"),
                      t("screening_q_usual_activities_3"),
                    ],
                    value: _usualActivities,
                    onChanged: (v) => setState(() => _usualActivities = v),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _Eq5dQuestion(
                    title: t("screening_q_pain"),
                    options: [
                      t("screening_q_pain_1"),
                      t("screening_q_pain_2"),
                      t("screening_q_pain_3"),
                    ],
                    value: _painDiscomfort,
                    onChanged: (v) => setState(() => _painDiscomfort = v),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _Eq5dQuestion(
                    title: t("screening_q_anxiety"),
                    options: [
                      t("screening_q_anxiety_1"),
                      t("screening_q_anxiety_2"),
                      t("screening_q_anxiety_3"),
                    ],
                    value: _anxietyDepression,
                    onChanged: (v) => setState(() => _anxietyDepression = v),
                  ),

                  SizedBox(height: TaqaUiScale.h(24)),

                  // ── PHQ-2 ──
                  _SectionLabel(label: t("screening_phq2_section")),
                  SizedBox(height: TaqaUiScale.h(12)),

                  _Phq2Question(
                    title: t("screening_q_interest"),
                    options: [
                      t("screening_phq_0"),
                      t("screening_phq_1"),
                      t("screening_phq_2"),
                      t("screening_phq_3"),
                    ],
                    value: _q1Interest,
                    onChanged: (v) => setState(() => _q1Interest = v),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _Phq2Question(
                    title: t("screening_q_mood"),
                    options: [
                      t("screening_phq_0"),
                      t("screening_phq_1"),
                      t("screening_phq_2"),
                      t("screening_phq_3"),
                    ],
                    value: _q2Mood,
                    onChanged: (v) => setState(() => _q2Mood = v),
                  ),

                  SizedBox(height: TaqaUiScale.h(24)),
                  _SubmitButton(
                    loading: _submitting,
                    label: t("screening_submit"),
                    onTap: (_allAnswered && !_submitting) ? _submit : null,
                  ),
                  SizedBox(height: TaqaUiScale.h(40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Sub-widgets ─────────────────────────

class _DaysRemainingChip extends StatelessWidget {
  const _DaysRemainingChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: TaqaUiScale.insetsLTRB(10, 4, 10, 4),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE4e93b.withValues(alpha: 0.25),
          borderRadius: TaqaUiScale.radius(10),
        ),
        child: Text(
          t("screening_days_remaining").replaceAll("{days}", "$days"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(11),
            fontWeight: FontWeight.w600,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
        fontSize: TaqaUiScale.sp(10),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8,
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
      ),
    );
  }
}

/// EQ-5D-3L: 3 radio options valued 1, 2, 3
class _Eq5dQuestion extends StatelessWidget {
  const _Eq5dQuestion({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      title: title,
      child: Column(
        children: List.generate(options.length, (i) {
          final optionValue = i + 1;
          return _RadioTile(
            label: options[i],
            selected: value == optionValue,
            onTap: () => onChanged(optionValue),
          );
        }),
      ),
    );
  }
}

/// PHQ-2: 4 radio options valued 0, 1, 2, 3
class _Phq2Question extends StatelessWidget {
  const _Phq2Question({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      title: title,
      child: Column(
        children: List.generate(options.length, (i) {
          return _RadioTile(
            label: options[i],
            selected: value == i,
            onTap: () => onChanged(i),
          );
        }),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          child,
        ],
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: TaqaUiScale.radius(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(6)),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: TaqaUiScale.w(20),
              color: selected
                  ? TaqaUiColors.unnamedColor1c1d17
                  : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.3),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(13),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? TaqaUiColors.unnamedColor1c1d17
                      : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  final bool loading;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled
          ? TaqaUiColors.unnamedColorE4e93b.withValues(alpha: 0.4)
          : TaqaUiColors.unnamedColorE4e93b,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Center(
            child: loading
                ? SizedBox(
                    width: TaqaUiScale.w(18),
                    height: TaqaUiScale.h(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  )
                : Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 12 / 10,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
