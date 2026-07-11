import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../auth/login.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class VerificationSuccessPage extends StatelessWidget {
  final String email;
  final bool isExpert;
  final bool canContinue;

  const VerificationSuccessPage({
    super.key,
    required this.email,
    required this.isExpert,
    required this.canContinue,
  });

  void _continue(BuildContext context) {
    if (canContinue) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isExpert
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (_) => false,
      );
      return;
    }

    // If we don't have a token, ask the user to log in to continue.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage(prefilledEmail: email)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: t.translate("verification_title"),
        showBackButton: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: TaqaUiScale.h(30)),
                  Container(
                    width: TaqaUiScale.w(88),
                    height: TaqaUiScale.w(88),
                    decoration: const BoxDecoration(
                      color: TaqaUiColors.unnamedColorE4e93b,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      size: TaqaUiScale.w(44),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(20)),
                  Text(
                    t.translate("verified_success"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(18),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(10)),
                  Text(
                    canContinue
                        ? t.translate("common_continue")
                        : t.translate("verification_login_required"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(14),
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
            child: TaqaFilledButton(
              label: canContinue
                  ? t.translate("common_continue")
                  : t.translate("login"),
              onTap: () => _continue(context),
            ),
          ),
        ],
      ),
    );
  }
}
