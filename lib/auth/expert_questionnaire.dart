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
import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import 'questionnaire.dart';
import '../main/main_layout.dart';
import '../screens/welcome.dart';
import '../services/auth/profile_service.dart';
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
  bool _switchingAccountType = false;

  String _t(String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TaqaPageAppBar(
        title: _t("expert_questionnaire_title"),
        backgroundColor: TaqaUiColors.white,
        showBackButton: !_started,
        leading: TaqaBackButton(onPressed: _handleBack),
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
                  onCancel: _exitToWelcome,
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
          TaqaFilledButton(
            label: _t("start_questionnaire"),
            onTap: () => setState(() => _started = true),
          ),
          SizedBox(height: TaqaUiScale.h(6)),
          TaqaTextActionButton(
            label: _t("switch_to_personalized_form"),
            onTap: _switchingAccountType ? null : _switchToPersonalizedForm,
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          TaqaTextActionButton(label: _t("cancel"), onTap: _exitToWelcome),
        ],
      ),
    );
  }

  void _exitToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
      (_) => false,
    );
  }

  void _handleBack() {
    if (_started) {
      setState(() => _started = false);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _exitToWelcome();
  }

  Future<void> _switchToPersonalizedForm() async {
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: _t("switch_account_type_title"),
      message: _t("switch_to_personalized_message"),
      cancelLabel: _t("switch_account_type_cancel"),
      confirmLabel: _t("switch_account_type_confirm"),
    );
    if (!mounted || !confirmed) return;

    setState(() => _switchingAccountType = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) {
        throw Exception(_t("user_missing"));
      }
      await ProfileApi.updateAccountType(userId: userId, accountType: "client");
      await AccountStorage.setIsExpert(false);
      await AccountStorage.setQuestionnaireDone(false);
      await AccountStorage.setExpertQuestionnaireDone(false);
      await AccountStorage.setCoachApplicationStatus(null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const QuestionnairePage()),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst("Exception: ", "").trim();
      AppToast.show(
        context,
        message.isEmpty ? _t("switch_account_type_failed") : message,
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _switchingAccountType = false);
    }
  }

  Future<void> _submit(Map<String, dynamic> values) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final t = AppLocalizations.of(context);
    try {
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
      await ExpertQuestionnaireApi.submit(payload);
      await AccountStorage.setExpertQuestionnaireDone(true);
      if (!mounted) return;
      AppToast.show(context, _t("save_success"), type: AppToastType.success);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainLayout(initialIndex: MainLayout.coachTabIndex),
        ),
        (_) => false,
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
