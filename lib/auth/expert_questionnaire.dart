import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../widgets/primary_button.dart';
import '../widgets/questionnaire/questionnaire_info_chip.dart';
import '../widgets/questionnaire/questionnaire_section_row.dart';
import '../widgets/questionnaire/expert_questionnaire_form.dart';
import '../core/account_storage.dart';
import '../widgets/app_toast.dart';
import 'expert_submission_success.dart';
import '../services/expert_questionnaire_service.dart';

class ExpertQuestionnairePage extends StatefulWidget {
  const ExpertQuestionnairePage({super.key});

  @override
  State<ExpertQuestionnairePage> createState() => _ExpertQuestionnairePageState();
}

class _ExpertQuestionnairePageState extends State<ExpertQuestionnairePage> {
  bool _started = false;
  bool _submitting = false;

  String _t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_t("expert_questionnaire_title")),
        centerTitle: true,
      ),
      backgroundColor: cs.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _started
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: ExpertQuestionnaireForm(
                  onSubmit: _submitting ? null : _submit,
                  submitting: _submitting,
                ),
              )
            : _buildIntro(theme, cs),
      ),
    );
  }

  Widget _buildIntro(ThemeData theme, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t("expert_questionnaire_intro_title"),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t("expert_questionnaire_intro_text"),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QuestionnaireInfoChip(
                icon: Icons.format_list_numbered,
                label: _t("expert_questionnaire_chip_count"),
              ),
              QuestionnaireInfoChip(
                icon: Icons.timer_outlined,
                label: _t("expert_questionnaire_chip_time"),
              ),
              QuestionnaireInfoChip(
                icon: Icons.verified_user_outlined,
                label: _t("expert_questionnaire_chip_quality"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionnaireSectionRow(
                    icon: Icons.school_outlined,
                    title: _t("expert_section_experience"),
                    subtitle: _t("expert_section_experience_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.stacked_line_chart_outlined,
                    title: _t("expert_section_specialty"),
                    subtitle: _t("expert_section_specialty_sub"),
                  ),
                  const SizedBox(height: 8),
                  QuestionnaireSectionRow(
                    icon: Icons.groups_outlined,
                    title: _t("expert_section_clients"),
                    subtitle: _t("expert_section_clients_sub"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: PrimaryWhiteButton(
              onPressed: () => setState(() => _started = true),
              child: Text(_t("start_questionnaire")),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: cs.outlineVariant),
                foregroundColor: cs.onSurface.withValues(alpha: 0.8),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t("cancel")),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(Map<String, dynamic> values) async {
    final t = AppLocalizations.of(context);
    final expertId = await AccountStorage.getUserId();
    if (expertId == null) {
      if (!mounted) return;
      AppToast.show(context, t.translate("user_missing"), type: AppToastType.error);
      return;
    }

    final payload = {
      "expert_id": expertId,
      ...values,
    };

    setState(() => _submitting = true);
    try {
      await ExpertQuestionnaireApi.submit(payload);
      await AccountStorage.setExpertQuestionnaireDone(true);
      if (!mounted) return;
      AppToast.show(context, _t("save_success"), type: AppToastType.success);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExpertSubmissionSuccessPage()),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, "$e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
