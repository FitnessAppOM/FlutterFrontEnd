import 'package:flutter/material.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';
import '../widgets/questionnaire/expert_questionnaire_form.dart';
import '../core/account_storage.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import 'expert_submission_success.dart';
import '../services/core/expert_questionnaire_service.dart';

class ExpertQuestionnairePage extends StatefulWidget {
  const ExpertQuestionnairePage({super.key});

  @override
  State<ExpertQuestionnairePage> createState() =>
      _ExpertQuestionnairePageState();
}

class _ExpertQuestionnairePageState extends State<ExpertQuestionnairePage> {
  bool _started = false;
  bool _submitting = false;

  String _t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TaqaPageAppBar(
        title: _t("expert_questionnaire_title"),
        backgroundColor: TaqaUiColors.white,
        showBackButton: false,
      ),
      backgroundColor: TaqaUiColors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _started
            ? Padding(
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
                child: ExpertQuestionnaireForm(
                  onSubmit: _submitting ? null : _submit,
                  submitting: _submitting,
                ),
              )
            : Column(
                children: [
                  Expanded(child: _buildIntro()),
                  _buildFooterButtons(),
                ],
              ),
      ),
    );
  }

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t("expert_questionnaire_intro_text"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(24)),
          Text(
            _t("expert_questionnaire_intro_title"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(20),
              fontWeight: FontWeight.w700,
              height: 26 / 20,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(20)),
          _ExpertSection(
            title: _t("expert_section_experience"),
            subtitle: _t("expert_section_experience_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _ExpertSection(
            title: _t("expert_section_specialty"),
            subtitle: _t("expert_section_specialty_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _ExpertSection(
            title: _t("expert_section_clients"),
            subtitle: _t("expert_section_clients_sub"),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Padding(
      padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilledActionButton(
            label: _t("start_questionnaire"),
            onTap: () => setState(() => _started = true),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaTextActionButton(
            label: _t("cancel"),
            onTap: () => Navigator.of(context).pop(),
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
      AppToast.show(
        context,
        t.translate("user_missing"),
        type: AppToastType.error,
      );
      return;
    }

    final payload = {"expert_id": expertId, ...values};

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

class _ExpertSection extends StatelessWidget {
  const _ExpertSection({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w700,
            height: 12 / 10,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(2)),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w400,
            height: 12 / 10,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ],
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  const _FilledActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.unnamedColorE4e93b,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
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
