import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';
import '../auth/questionnaire.dart';
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';
import '../localization/app_localizations.dart';

class WelcomePage extends StatefulWidget {
  final void Function(Locale)? onChangeLanguage;

  const WelcomePage({
    super.key,
    this.onChangeLanguage,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;
  bool lastVerified = false;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getEmail();
    final n = await AccountStorage.getName();
    final v = await AccountStorage.isVerified();

    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastVerified = v;
      lastName = v ? n : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context); // 🔥 Translator

    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final hasVerifiedAccount = hasAccount && lastVerified;
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔥 Language switch buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => widget.onChangeLanguage?.call(const Locale('en')),
                    child: const Text("English", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => widget.onChangeLanguage?.call(const Locale('ar')),
                    child: const Text("العربية", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/BGWELC.jpg',
                        fit: BoxFit.cover,
                      ),
                      Container(color: Colors.black.withOpacity(0.25)),
                    ],
                  ),
                ),
              ),

              Gaps.h24,

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 Translated title
                  Text(
                    t.translate("welcome_tagline"),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Gaps.h24,

                  if (hasVerifiedAccount) ...[
                    DividerWithLabel(label: t.translate("saved_accounts")),
                    Gaps.h12,
                    SavedAccountTile(
                      title: "${t.translate("login_as")} $displayName",
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const QuestionnairePage()),
                        );
                      },
                      onMenu: () {},
                    ),
                    Gaps.h20,
                  ],

                  // 🔥 LOGIN BUTTON
                  PrimaryWhiteButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasVerifiedAccount
                          ? t.translate("login_with_another")
                          : t.translate("login"),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Gaps.h20,

                  // 🔥 SIGNUP ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.translate("new_to_taqa"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: Text(
                          t.translate("signup"),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
