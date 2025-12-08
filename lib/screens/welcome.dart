import 'package:flutter/material.dart';
import '../widgets/lang_button.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import '../core/locale_controller.dart';
import '../config/base_url.dart';
import '../services/profile_service.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../widgets/app_toast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


// -----------------------------------------------------------------------------
// FIX: Model must be OUTSIDE the widget
// -----------------------------------------------------------------------------
class UserCheckResult {
  final int id;
  UserCheckResult(this.id);
}


// -----------------------------------------------------------------------------
// WELCOME PAGE
// -----------------------------------------------------------------------------
class WelcomePage extends StatefulWidget {
  final void Function(Locale)? onChangeLanguage;
  final bool fromLogout;

  const WelcomePage({
    super.key,
    this.onChangeLanguage,
    this.fromLogout = false,   // <-- ADD THIS
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;
  bool lastVerified = false;
  bool lastIsExpert = false;
  bool lastQuestionnaireDone = false;
  bool lastExpertQuestionnaireDone = false;

  void _changeLanguage(Locale locale) {
    final callback = widget.onChangeLanguage ?? localeController.setLocale;
    callback(locale);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  // -----------------------------------------------------------------------------
  // CHECK USER IN BACKEND
  // -----------------------------------------------------------------------------
  Future<UserCheckResult?> checkUserExistsBackend(String email) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/check-user");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return UserCheckResult(json["user_id"]);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------------------------
  // LOAD LOCAL USER + AUTO LOGIN
  // -----------------------------------------------------------------------------
  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getEmail();
    final n = await AccountStorage.getName();
    final v = await AccountStorage.isVerified();
    final isExpert = await AccountStorage.isExpert();
    final qDone = await AccountStorage.isQuestionnaireDone();
    final qExpertDone = await AccountStorage.isExpertQuestionnaireDone();

  if (!mounted) return;

  //  Don't auto-redirect if coming from logout
  if (widget.fromLogout) {
    setState(() {
      lastEmail = e;
      lastVerified = v;
      lastIsExpert = isExpert;
      lastQuestionnaireDone = qDone;
      lastExpertQuestionnaireDone = qExpertDone;
      lastName = v ? n : null;
    });
    return;
  }

  // Normal auto-redirect
  if (e != null && e.isNotEmpty && v == true) {
    final exists = await checkUserExistsBackend(e);
    if (exists != null) {
      await _navigatePostAuth(
        userId: exists.id,
        isExpert: isExpert,
      );
      return;
    }
  }

  setState(() {
    lastEmail = e;
    lastVerified = v;
    lastIsExpert = isExpert;
    lastQuestionnaireDone = qDone;
    lastExpertQuestionnaireDone = qExpertDone;
    lastName = v ? n : null;
  });
}

  Future<void> _navigatePostAuth({
    required int userId,
    required bool isExpert,
  }) async {
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final serverDone = profile["filled_user_questionnaire"] == true;
      final hasData = serverDone || _hasQuestionnaireData(profile);
      if (serverDone) {
        await AccountStorage.setQuestionnaireDone(true);
        await AccountStorage.setExpertQuestionnaireDone(true);
      }
      if (!mounted) return;
      if (hasData) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => isExpert
                ? const ExpertQuestionnairePage()
                : const QuestionnairePage(),
          ),
          (route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isExpert
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (route) => false,
      );
    }
  }

  bool _hasQuestionnaireData(Map<String, dynamic> profile) {
    const keys = [
      "age",
      "fitness_goal",
      "training_days",
      "diet_type",
      "height_cm",
      "weight_kg",
      "sex",
    ];
    return keys.any((k) {
      final v = profile[k];
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty && s != "null";
    });
  }

  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

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
              // LANG BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LangButton(
                    label: "EN",
                    flag: "🇬🇧",
                    selected:
                        Localizations.localeOf(context).languageCode == "en",
                    onTap: () => _changeLanguage(const Locale('en')),
                  ),
                  LangButton(
                    label: "AR",
                    flag: "🇸🇦",
                    selected:
                        Localizations.localeOf(context).languageCode == "ar",
                    onTap: () => _changeLanguage(const Locale('ar')),
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
                      Container(color: Colors.black.withValues(alpha: 0.25)),
                    ],
                  ),
                ),
              ),

              Gaps.h24,

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      onTap: () async {
                        final email = lastEmail!;
                        final isExpert = lastIsExpert;

                        final exists = await checkUserExistsBackend(email);
                        if (exists == null) {
                          if (!mounted) return;
                          AppToast.show(
                            context,
                            t.translate("account_no_longer_exists"),
                            type: AppToastType.error,
                          );
                          return;
                        }

                            await AccountStorage.saveUserSession(
                              userId: exists.id,
                              email: email,
                              name: displayName,
                              verified: true,
                              isExpert: isExpert,
                            );

                        await _navigatePostAuth(
                          userId: exists.id,
                          isExpert: isExpert,
                        );
                      },
                      onMenu: () {},
                    ),

                    Gaps.h20,
                  ],

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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
