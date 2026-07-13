import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import 'daily_journal.dart';
import '../core/locale_controller.dart';
import '../config/base_url.dart';
import '../services/auth/profile_service.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/core/daily_provider_push_service.dart';
import '../services/auth/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';


// -----------------------------------------------------------------------------
// FIX: Model must be OUTSIDE the widget
// -----------------------------------------------------------------------------
class UserCheckResult {
  final int? id;
  final bool offline;
  const UserCheckResult({this.id, this.offline = false});
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
  bool _appleLoggingIn = false;

  void _changeLanguage(Locale locale) {
    final callback = widget.onChangeLanguage ?? localeController.setLocale;
    callback(locale);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    NavigationService.setNotificationNavigationReady(false);
    _loadLastUser();
  }

  // -----------------------------------------------------------------------------
  // CHECK USER IN BACKEND
  // -----------------------------------------------------------------------------
  static const Duration _checkTimeout = Duration(seconds: 6);

  Future<UserCheckResult> checkUserExistsBackend(String email) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/check-user");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(_checkTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is! Map) return const UserCheckResult();
        final id = data["user_id"];
        if (id == null) return const UserCheckResult();
        final userId = id is int ? id : int.tryParse(id.toString());
        if (userId == null) return const UserCheckResult();
        return UserCheckResult(id: userId);
      }

      return const UserCheckResult();
    } on SocketException {
      return const UserCheckResult(offline: true);
    } on TimeoutException {
      return const UserCheckResult(offline: true);
    } on http.ClientException {
      return const UserCheckResult(offline: true);
    } catch (_) {
      return const UserCheckResult();
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
    final savedUserId = await AccountStorage.getUserId();
    final token = await AccountStorage.getAccessToken();
    final hasSession = savedUserId != null &&
        savedUserId > 0 &&
        token != null &&
        token.trim().isNotEmpty;

  if (!mounted) return;

  //  Don't auto-redirect if coming from logout
  if (widget.fromLogout) {
    setState(() {
      lastEmail = e;
      lastVerified = v;
      lastIsExpert = isExpert;
      lastQuestionnaireDone = qDone;
      lastExpertQuestionnaireDone = qExpertDone;
      final trimmedName = n?.trim() ?? '';
      lastName = trimmedName.isNotEmpty ? trimmedName : null;
      lastAuthProvider = provider;
    });
    return;
  }

  // Normal auto-redirect
  // Auto-redirect only if verified AND questionnaire was completed
  final questionnaireDone = qDone || qExpertDone;
  if (e != null && e.isNotEmpty && v == true && questionnaireDone) {
    if (hasSession) {
      final exists = await checkUserExistsBackend(e);
      if (exists.offline) {
        await _navigateOfflineMain();
        return;
      }
      if (exists.id != null) {
        await _navigatePostAuth(
          userId: exists.id!,
        );
        return;
      }
    }
  }

  setState(() {
    lastEmail = e;
    lastVerified = v;
    lastIsExpert = isExpert;
    lastQuestionnaireDone = qDone;
    lastExpertQuestionnaireDone = qExpertDone;
    final trimmedName = n?.trim() ?? '';
    lastName = trimmedName.isNotEmpty ? trimmedName : null;
    lastAuthProvider = provider;
  });
}

  Future<void> _navigatePostAuth({
    required int userId,
  }) async {
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final serverDone = profile["filled_user_questionnaire"] == true;
      final expertQuestionnaireDone =
          profile["filled_expert_questionnaire"] == true;
      final isExpert = profile["is_expert"] == true;
      final hasData = serverDone || _hasQuestionnaireData(profile);
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(expertQuestionnaireDone);
      await AccountStorage.setIsExpert(isExpert);
      if (!mounted) return;
      if (NavigationService.isOnJournalPage) {
        return;
      }
      if (hasData) {
        final expertAiPending =
            isExpert && NavigationService.expertAiUpdatesNotificationPending;
        if (expertAiPending) {
          NavigationService.consumeExpertAiUpdatesNotification();
        }
        final directNotificationTarget =
            await NavigationService.consumeDirectNotificationTarget();
        final target = directNotificationTarget ??
            (NavigationService.journalNotificationPending
            ? const DailyJournalPage()
            : (NavigationService.dietNotificationPending
                ? const MainLayout(initialIndex: 0)
                : (expertAiPending
                    ? const MainLayout(
                        initialIndex: MainLayout.coachTabIndex,
                        autoOpenExpertDashboard: true,
                      )
                    : const MainLayout())));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => target),
          (route) => false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationService.setNotificationNavigationReady(true);
          NavigationService.flushPendingNotificationNavigation();
        });
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
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('deactivated') || msg.contains('reactivate')) {
        return;
      }
      final fallbackIsExpert = await AccountStorage.isExpert();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => fallbackIsExpert
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _navigateOfflineMain() async {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (route) => false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        final ctx = NavigationService.navigatorKey.currentContext;
        if (ctx == null) return;
        final t = AppLocalizations.of(ctx);
        AppToast.show(
          ctx,
          t.translate("offline_mode") ?? "Offline Mode",
          type: AppToastType.info,
        );
      });
    });
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
        isExpert: false,
        questionnaireDone: false,
        expertQuestionnaireDone: false,
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
      );

      NotificationService.refreshDailyJournalRemindersForCurrentUser();
      DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
      // Fitbit backfill now happens only on connect (backend).
    } finally {
      if (mounted) setState(() => _googleLoggingIn = false);
    }
  }

  Future<void> _handleAppleQuickLogin() async {
    if (_appleLoggingIn) return;
    final t = AppLocalizations.of(context);
    setState(() => _appleLoggingIn = true);
    try {
      final result = await signInWithApple();
      if (!mounted) return;
      if (result == null) {
        AppToast.show(
          context,
          t.translate("apple_failed"),
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
          t.translate("apple_failed"),
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
        isExpert: false,
        questionnaireDone: false,
        expertQuestionnaireDone: false,
        authProvider: "apple",
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
          t.translate("apple_failed"),
          type: AppToastType.error,
        );
        return;
      }

      if (!mounted) return;

      await _navigatePostAuth(
        userId: userId,
      );

      NotificationService.refreshDailyJournalRemindersForCurrentUser();
      DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
    } finally {
      if (mounted) setState(() => _appleLoggingIn = false);
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
    final t = AppLocalizations.of(context);

    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final hasVerifiedAccount = hasAccount && lastVerified;
    final isGoogleAccount = lastAuthProvider == "google";
    final isAppleAccount = lastAuthProvider == "apple";
    final displayName = (lastName != null && lastName!.trim().isNotEmpty)
        ? lastName!.trim()
        : (lastEmail?.split('@').first.trim() ?? '');

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LANGUAGE SWITCH (same TaqaRangeTab used in Settings)
              Row(
                children: [
                  Expanded(
                    child: TaqaRangeTab(
                      label: "English",
                      selected:
                          Localizations.localeOf(context).languageCode == "en",
                      onTap: () => _changeLanguage(const Locale('en')),
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(15)),
                  Expanded(
                    child: TaqaRangeTab(
                      label: "Arabic",
                      selected:
                          Localizations.localeOf(context).languageCode == "ar",
                      onTap: () => _changeLanguage(const Locale('ar')),
                    ),
                  ),
                ],
              ),

              SizedBox(height: TaqaUiScale.h(16)),

              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColor1c1d17,
                    borderRadius: TaqaUiScale.radius(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: TaqaUiScale.h(-50),
                        right: TaqaUiScale.w(-60),
                        child: Opacity(
                          opacity: 0.12,
                          child: Transform.rotate(
                            angle: 0.5,
                            child: Image.asset(
                              'lib/TaqaUI/Assets/Taqa_Fitness_Favicon.png',
                              width: TaqaUiScale.w(240),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: TaqaUiScale.h(-60),
                        left: TaqaUiScale.w(-70),
                        child: Opacity(
                          opacity: 0.10,
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Image.asset(
                              'lib/TaqaUI/Assets/Taqa_Fitness_Favicon.png',
                              width: TaqaUiScale.w(200),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: TaqaUiScale.radius(28),
                          boxShadow: [
                            BoxShadow(
                              color: TaqaUiColors.unnamedColorE4e93b
                                  .withValues(alpha: 0.35),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'lib/TaqaUI/Assets/Taqa_Fitness_Favicon.png',
                          width: TaqaUiScale.w(140),
                          height: TaqaUiScale.w(140),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: TaqaUiScale.h(24)),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.translate("welcome_tagline"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(20),
                      fontWeight: FontWeight.w700,
                      height: 26 / 20,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),

                  SizedBox(height: TaqaUiScale.h(24)),

                  if (hasVerifiedAccount) ...[
                    DividerWithLabel(label: t.translate("saved_accounts")),
                    SizedBox(height: TaqaUiScale.h(12)),

                    SavedAccountTile(
                      title: "${t.translate("login_as")} $displayName",
                      onTap: () {
                        if (isGoogleAccount) {
                          _handleGoogleQuickLogin();
                          return;
                        }
                        if (isAppleAccount) {
                          _handleAppleQuickLogin();
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

                    SizedBox(height: TaqaUiScale.h(20)),
                  ],

                  TaqaFilledButton(
                    label: hasVerifiedAccount
                        ? t.translate("login_with_another")
                        : t.translate("login"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                  ),

                  SizedBox(height: TaqaUiScale.h(20)),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.translate("new_to_taqa"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w400,
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.6,
                          ),
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
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(13),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: TaqaUiColors.unnamedColor1c1d17,
                            color: TaqaUiColors.unnamedColor1c1d17,
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
