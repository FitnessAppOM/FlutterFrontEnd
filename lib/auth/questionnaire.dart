import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/questionnaire/questionnaire_form.dart';
import '../services/core/questionnaire_service.dart';
import '../core/account_storage.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../screens/generating_training_screen.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: TaqaPageAppBar(
        title: t.translate("questionnaire_title"),
        backgroundColor: TaqaUiColors.white,
        showBackButton: false,
      ),
      backgroundColor: TaqaUiColors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _started
            ? Padding(
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
                child: _buildFormUI(context),
              )
            : Column(
                children: [
                  Expanded(child: _buildIntro(context)),
                  _buildFooterButtons(context),
                ],
              ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final t = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate("questionnaire_intro_text"),
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
            t.translate("questionnaire_intro_title"),
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
          _QuestionnaireSection(
            title: t.translate("section_basics_title"),
            subtitle: t.translate("section_basics_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _QuestionnaireSection(
            title: t.translate("section_goals_title"),
            subtitle: t.translate("section_goals_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _QuestionnaireSection(
            title: t.translate("section_training_title"),
            subtitle: t.translate("section_training_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _QuestionnaireSection(
            title: t.translate("section_nutrition_title"),
            subtitle: t.translate("section_nutrition_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          _QuestionnaireSection(
            title: t.translate("section_lifestyle_title"),
            subtitle: t.translate("section_lifestyle_sub"),
          ),
          SizedBox(height: TaqaUiScale.h(24)),
          Text(
            t.translate("questionnaire_consent_notice"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w400,
              height: 16 / 11,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaqaFilledButton(
            label: t.translate("start_questionnaire"),
            onTap: () => setState(() => _started = true),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Text(
            t.translate("update_later"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI(BuildContext context) {
    final t = AppLocalizations.of(context);

    return QuestionnaireForm(
      onSubmit: (values) async {
        try {
          final userId = await AccountStorage.getUserId();
          if (userId == null) {
            AppToast.show(
              context,
              t.translate("user_missing"),
              type: AppToastType.error,
            );
            return;
          }

          final payload = {"user_id": userId.toString(), ...values};

          await QuestionnaireApi.submitQuestionnaire(payload);

          if (!mounted) return;
          AppToast.show(
            context,
            t.translate("save_success"),
            type: AppToastType.success,
          );
          await AccountStorage.setQuestionnaireDone(true);
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GeneratingTrainingScreen()),
            (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          AppToast.show(
            context,
            "${t.translate("save_error")}: $e",
            type: AppToastType.error,
          );
        }
      },
    );
  }
}

class _QuestionnaireSection extends StatelessWidget {
  const _QuestionnaireSection({required this.title, required this.subtitle});

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
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 20 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(4)),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w400,
            height: 18 / 13,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
