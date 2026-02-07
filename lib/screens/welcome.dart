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
import '../services/auth/profile_service.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../widgets/app_toast.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/metrics/daily_metrics_sync.dart';
import '../services/auth/auth_service.dart';
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
  String? lastAuthProvider;
  bool _googleLoggingIn = false;

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
        final data = jsonDecode(res.body);
        if (data is! Map) return null;
        final id = data["user_id"];
        if (id == null) return null;
        final userId = id is int ? id : int.tryParse(id.toString());
        if (userId == null) return null;
        return UserCheckResult(userId);
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
    final provider = await AccountStorage.getAuthProvider();

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
      lastAuthProvider = provider;
    });
    return;
  }

  // Skip auto-redirect when app was launched from a notification deep link.
  if (NavigationService.launchedFromNotificationPayload) {
    setState(() {
      lastEmail = e;
      lastVerified = v;
      lastIsExpert = isExpert;
      lastQuestionnaireDone = qDone;
      lastExpertQuestionnaireDone = qExpertDone;
      lastName = v ? n : null;
      lastAuthProvider = provider;
    });
    return;
  }

  // Normal auto-redirect
  // Auto-redirect only if verified AND questionnaire was completed
  final questionnaireDone = qDone || qExpertDone;
  if (e != null && e.isNotEmpty && v == true && questionnaireDone) {
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
    lastAuthProvider = provider;
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
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(serverDone);
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

  Future<void> _handleGoogleQuickLogin() async {
    if (_googleLoggingIn) return;
    final t = AppLocalizations.of(context);
    setState(() => _googleLoggingIn = true);
    try {
      final result = await signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        AppToast.show(
          context,
          t.translate("google_failed"),
          type: AppToastType.error,
        );
        return;
      }

      final rawId = result["user_id"] ?? result["id"];
      final int userId =
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
      final accessToken = (result["access_token"] ??
              result["accessToken"] ??
              result["jwt"] ??
              result["token"])
          ?.toString()
          ?.trim();

      if (userId <= 0 || accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        AppToast.show(
          context,
          t.translate("google_failed"),
          type: AppToastType.error,
        );
        return;
      }

      final email = (result["email"] ?? "").toString();
      final name = (result["name"] ?? email.split("@").first).toString();

      await AccountStorage.saveUserSession(
        userId: userId,
        email: email,
        name: name,
        verified: true,
        token: accessToken,
        isExpert: lastIsExpert,
        questionnaireDone: await AccountStorage.isQuestionnaireDone(),
        expertQuestionnaireDone:
            await AccountStorage.isExpertQuestionnaireDone(),
        authProvider: "google",
      );

      final savedId = await AccountStorage.getUserId();
      final savedToken = await AccountStorage.getAccessToken();
      if (savedId == null ||
          savedId <= 0 ||
          savedToken == null ||
          savedToken.isEmpty) {
        if (!mounted) return;
        AppToast.show(
          context,
          t.translate("google_failed"),
          type: AppToastType.error,
        );
        return;
      }

      if (!mounted) return;

      await _navigatePostAuth(
        userId: userId,
        isExpert: lastIsExpert,
      );

      NotificationService.refreshDailyJournalRemindersForCurrentUser();
      DailyMetricsSync().pushIfNewDay().catchError((_) {});
    } finally {
      if (mounted) setState(() => _googleLoggingIn = false);
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
    final isGoogleAccount = lastAuthProvider == "google";
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
                      onTap: () {
                        if (isGoogleAccount) {
                          _handleGoogleQuickLogin();
                          return;
                        }
                        // Email accounts: go to login with email prefilled so user enters password.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
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
