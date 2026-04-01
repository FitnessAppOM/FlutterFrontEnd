import 'package:flutter/material.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/screenings/screening_service.dart';
import '../../theme/app_theme.dart';
import '../app_toast.dart';

/// Full-screen modal that collects 7 screening questions
/// (EQ-5D-3L + PHQ-2) and submits them.
class ScreeningFormSheet extends StatefulWidget {
  const ScreeningFormSheet({
    super.key,
    required this.pending,
  });

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
        AppToast.show(context, t("screening_submitted"),
            type: AppToastType.success);
        Navigator.of(context).pop(true);
      }
    } on ScreeningConflictException {
      if (mounted) {
        AppToast.show(context, t("screening_already_submitted"),
            type: AppToastType.info);
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
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t("screening_title"),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: const CloseButton(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            Text(t("screening_subtitle"),
                style: AppTextStyles.small),
            if (days != null) ...[
              const SizedBox(height: 8),
              _DaysRemainingChip(days: days),
            ],
            const SizedBox(height: 20),

            // ── EQ-5D-3L ──
            _SectionLabel(label: t("screening_eq5d_section")),
            const SizedBox(height: 12),

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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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

            const SizedBox(height: 28),

            // ── PHQ-2 ──
            _SectionLabel(label: t("screening_phq2_section")),
            const SizedBox(height: 12),

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
            const SizedBox(height: 16),
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

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _allAnswered && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t("screening_submit")),
              ),
            ),
            const SizedBox(height: 40),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          t("screening_days_remaining").replaceAll("{days}", "$days"),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subtitle),
          const SizedBox(height: 10),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.accent : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
