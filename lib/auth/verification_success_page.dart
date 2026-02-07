import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../auth/login.dart';

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
      MaterialPageRoute(
        builder: (_) => LoginPage(prefilledEmail: email),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("verification_title")),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.verified, color: AppColors.accent, size: 64),
            const SizedBox(height: 16),
            Text(
              t.translate("verified_success"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              canContinue
                  ? t.translate("common_continue")
                  : t.translate("verification_login_required"),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            PrimaryWhiteButton(
              onPressed: () => _continue(context),
              child: Text(
                canContinue
                    ? t.translate("common_continue")
                    : t.translate("login"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
