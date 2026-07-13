import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../services/auth/auth_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_text_field.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';

import '../localization/app_localizations.dart';
import '../screens/ForgetPassword/forgot_password_page.dart';
import '../main/main_layout.dart'; // <-- MAIN PAGE
import '../screens/daily_journal.dart';
import '../screens/account_restore_page.dart';
import 'email_verification_page.dart';
import '../services/auth/profile_service.dart';
import 'questionnaire.dart';
import 'expert_questionnaire.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../services/core/notification_service.dart';
import '../services/core/navigation_service.dart';
import '../services/core/daily_provider_push_service.dart';

class LoginPage extends StatefulWidget {
  final String? prefilledEmail;
  final bool autoGoogle;
  const LoginPage({super.key, this.prefilledEmail, this.autoGoogle = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;

  String? lastEmail;
  String? lastName;
  bool lastVerified = false;
  bool lastIsExpert = false;
  bool lastQuestionnaireDone = false;
  bool lastExpertQuestionnaireDone = false;
  String? lastAuthProvider;

  @override
  void initState() {
    super.initState();
    NavigationService.setNotificationNavigationReady(false);
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      email.text = widget.prefilledEmail!;
    }
    _loadLastUser();
    if (widget.autoGoogle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || loading) return;
        handleGoogleLogin();
      });
    }
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getEmail();
    final n = await AccountStorage.getName();
    final v = await AccountStorage.isVerified();
    final isExpert = await AccountStorage.isExpert();
    final qDone = await AccountStorage.isQuestionnaireDone();
    final qExpertDone = await AccountStorage.isExpertQuestionnaireDone();
    final provider = await AccountStorage.getAuthProvider();
    final userId = await AccountStorage.getUserId();
    final token = await AccountStorage.getAccessToken();
    final validSession =
        userId != null &&
        userId > 0 &&
        token != null &&
        token.trim().isNotEmpty;

    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = v ? n : null;
      lastVerified = v;
      lastIsExpert = isExpert;
      lastQuestionnaireDone = qDone;
      lastExpertQuestionnaireDone = qExpertDone;
      lastAuthProvider = provider;
    });
  }

  Future<void> _navigatePostAuth({required int userId}) async {
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
        final target =
            directNotificationTarget ??
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

  Future<void> login() async {
    final t = AppLocalizations.of(context);

    final mail = email.text.trim();
    final pass = password.text;

    if (mail.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("error_required_fields"),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/auth/login");
    final body = jsonEncode({"email": mail, "password": pass});

    try {
      final response = await http
          .post(url, headers: {"Content-Type": "application/json"}, body: body)
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? data;
      try {
        data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : null;
      } catch (_) {}

      if (response.statusCode == 200) {
        final rawId = data?['user_id'] ?? data?['id'];
        final int userId = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '') ?? 0;
        final token =
            (data?['access_token'] ??
                    data?['accessToken'] ??
                    data?['jwt'] ??
                    data?['token'])
                ?.toString()
                ?.trim();

        // Backend must return user_id and access_token; otherwise do not overwrite storage
        if (userId <= 0 || token == null || token.isEmpty) {
          if (!mounted) return;
          AppToast.show(
            context,
            t.translate("network_error"),
            type: AppToastType.error,
          );
          return;
        }

        final emailFromApi = (data?['email'] ?? mail).toString();
        final name =
            (data?['username'] ??
                    data?['full_name'] ??
                    emailFromApi.split('@').first)
                .toString();
        await AccountStorage.saveUserSession(
          userId: userId,
          email: emailFromApi,
          name: name,
          verified: true,
          token: token,
          isExpert: false,
          questionnaireDone: false,
          expertQuestionnaireDone: false,
          authProvider: "email",
        );

        // Verify session was stored (avoids "user id missing" if storage failed)
        final savedId = await AccountStorage.getUserId();
        final savedToken = await AccountStorage.getAccessToken();
        if (savedId == null ||
            savedId <= 0 ||
            savedToken == null ||
            savedToken.isEmpty) {
          if (!mounted) return;
          AppToast.show(
            context,
            t.translate("network_error"),
            type: AppToastType.error,
          );
          return;
        }

        if (!mounted) return;

        await _navigatePostAuth(userId: userId);

        // Fire-and-forget: do not block navigation if these fail.
        NotificationService.refreshDailyJournalRemindersForCurrentUser();
        DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});

        return;
      }

      final detail =
          (data?['detail'] ?? response.reasonPhrase ?? 'Login failed')
              .toString();

      // Email not verified
      if (response.statusCode == 403 &&
          detail.toLowerCase().contains('verify')) {
        if (!mounted) return;
        AppToast.show(context, detail, type: AppToastType.info);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationPage(email: mail)),
        );
        return;
      }

      final deactivated =
          response.statusCode == 403 &&
          (detail.toLowerCase().contains('deactivated') ||
              detail.toLowerCase().contains('reactivate'));
      if (deactivated) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AccountRestorePage(initialPayload: data, prefilledEmail: mail),
          ),
          (_) => false,
        );
        return;
      }

      if (!mounted) return;
      AppToast.show(context, detail, type: AppToastType.error);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("network_error")}: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleGoogleLogin() async {
    final t = AppLocalizations.of(context);

    if (!mounted) return;
    setState(() => loading = true);

    final result = await signInWithGoogle();

    if (!mounted) return;
    setState(() => loading = false);

    if (result == null) {
      AppToast.show(
        context,
        t.translate("google_failed"),
        type: AppToastType.error,
      );
      return;
    }

    final rawId = result["user_id"] ?? result["id"];
    final int userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final accessToken =
        (result["access_token"] ??
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

    AppToast.show(
      context,
      t.translate("google_success_message"),
      type: AppToastType.success,
    );

    await _navigatePostAuth(userId: userId);

    // Fire-and-forget: do not block navigation if these fail.
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
  }

  Future<void> handleAppleLogin() async {
    final t = AppLocalizations.of(context);

    if (!mounted) return;
    setState(() => loading = true);

    final result = await signInWithApple();

    if (!mounted) return;
    setState(() => loading = false);

    if (result == null) {
      AppToast.show(
        context,
        t.translate("apple_failed"),
        type: AppToastType.error,
      );
      return;
    }

    final rawId = result["user_id"] ?? result["id"];
    final int userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final accessToken =
        (result["access_token"] ??
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

    AppToast.show(
      context,
      t.translate("apple_success_message"),
      type: AppToastType.success,
    );

    await _navigatePostAuth(userId: userId);

    // Fire-and-forget: do not block navigation if these fail.
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSubmit =
        !loading && email.text.trim().isNotEmpty && password.text.isNotEmpty;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: t.translate("login_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      ),
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaqaTextField(
                  controller: email,
                  label: t.translate("email"),
                  hint: t.translate("email_hint"),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                TaqaTextField(
                  controller: password,
                  label: t.translate("password"),
                  hint: t.translate("password_hint"),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),

                if (lastAuthProvider != "google" && lastAuthProvider != "apple")
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        t.translate("forgot_password"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(12),
                          fontWeight: FontWeight.w600,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: TaqaUiScale.h(8)),
                TaqaFilledButton(
                  label: t.translate("login_btn"),
                  loading: loading,
                  onTap: canSubmit ? login : null,
                ),

                SizedBox(height: TaqaUiScale.h(20)),
                DividerWithLabel(label: t.translate("or")),
                SizedBox(height: TaqaUiScale.h(12)),

                if (Platform.isIOS) ...[
                  SocialButton.apple(
                    icon: Icons.apple,
                    text: t.translate("apple_login"),
                    onPressed: handleAppleLogin,
                  ),

                  SizedBox(height: TaqaUiScale.h(12)),
                ],

                SocialButton.dark(
                  icon: Icons.g_mobiledata,
                  text: t.translate("google_login"),
                  onPressed: handleGoogleLogin,
                ),

                SizedBox(height: TaqaUiScale.h(20)),

                if (lastVerified &&
                    (lastEmail ?? '').isNotEmpty &&
                    (lastAuthProvider == "google" ||
                        lastAuthProvider == "apple")) ...[
                  DividerWithLabel(label: t.translate("saved_accounts")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  SavedAccountTile(
                    title:
                        "${t.translate("login_as")} ${lastName ?? lastEmail!.split('@').first}",
                    onTap: loading
                        ? null
                        : () {
                            if (lastAuthProvider == "apple") {
                              handleAppleLogin();
                              return;
                            }
                            handleGoogleLogin();
                          },
                    onMenu: () {},
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
