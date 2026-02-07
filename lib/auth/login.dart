import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../services/auth/auth_service.dart';
import '../theme/spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';

import '../localization/app_localizations.dart';
import '../screens/ForgetPassword/forgot_password_page.dart';
import '../main/main_layout.dart';           // <-- MAIN PAGE
import 'email_verification_page.dart';
import '../services/auth/profile_service.dart';
import 'questionnaire.dart';
import 'expert_questionnaire.dart';
import '../widgets/app_toast.dart';
import '../services/core/notification_service.dart';
import '../services/metrics/daily_metrics_sync.dart';

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
        userId != null && userId > 0 && token != null && token.trim().isNotEmpty;

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
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic>? data;
      try {
        data = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : null;
      } catch (_) {}

      if (response.statusCode == 200) {
        final rawId = data?['user_id'] ?? data?['id'];
        final int userId =
            rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
        final token = (data?['access_token'] ??
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
        final name = (data?['username'] ??
                data?['full_name'] ??
                emailFromApi.split('@').first)
            .toString();
        final storedEmail = await AccountStorage.getEmail();
        final storedExpert = (storedEmail != null && storedEmail == emailFromApi)
            ? await AccountStorage.isExpert()
            : false;

        await AccountStorage.saveUserSession(
          userId: userId,
          email: emailFromApi,
          name: name,
          verified: true,
          token: token,
          isExpert: storedExpert,
          questionnaireDone: await AccountStorage.isQuestionnaireDone(),
          expertQuestionnaireDone:
              await AccountStorage.isExpertQuestionnaireDone(),
          authProvider: "email",
        );

        // Verify session was stored (avoids "user id missing" if storage failed)
        final savedId = await AccountStorage.getUserId();
        final savedToken = await AccountStorage.getAccessToken();
        if (savedId == null || savedId <= 0 || savedToken == null || savedToken.isEmpty) {
          if (!mounted) return;
          AppToast.show(
            context,
            t.translate("network_error"),
            type: AppToastType.error,
          );
          return;
        }

        if (!mounted) return;

        await _navigatePostAuth(
          userId: userId,
          isExpert: storedExpert,
        );

        // Fire-and-forget: do not block navigation if these fail.
        NotificationService.refreshDailyJournalRemindersForCurrentUser();
        DailyMetricsSync().pushIfNewDay().catchError((_) {});

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
      questionnaireDone: await AccountStorage.isQuestionnaireDone(),
      expertQuestionnaireDone:
          await AccountStorage.isExpertQuestionnaireDone(),
      authProvider: "google",
    );

    final savedId = await AccountStorage.getUserId();
    final savedToken = await AccountStorage.getAccessToken();
    if (savedId == null || savedId <= 0 || savedToken == null || savedToken.isEmpty) {
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

    await _navigatePostAuth(
      userId: userId,
      isExpert: false,
    );

    // Fire-and-forget: do not block navigation if these fail.
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    DailyMetricsSync().pushIfNewDay().catchError((_) {});
  }




  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSubmit =
        !loading && email.text.trim().isNotEmpty && password.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("login_title")),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.translate("email"),
                hintText: t.translate("email_hint"),
              ),
            ),
            Gaps.h12,
            TextField(
              controller: password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.translate("password"),
                hintText: t.translate("password_hint"),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ForgotPasswordPage()),
                  );
                },
                child: Text(t.translate("forgot_password")),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: canSubmit ? login : null,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(t.translate("login_btn")),
              ),
            ),

            Gaps.h20,
            DividerWithLabel(label: t.translate("or")),
            Gaps.h12,

            SocialButton.apple(
              icon: Icons.apple,
              text: t.translate("apple_login"),
              onPressed: () {},
            ),

            Gaps.h12,

            SocialButton.dark(
              icon: Icons.g_mobiledata,
              text: t.translate("google_login"),
              onPressed: handleGoogleLogin,
            ),

            Gaps.h20,

            if (lastVerified &&
                (lastEmail ?? '').isNotEmpty &&
                lastAuthProvider == "google") ...[
              DividerWithLabel(label: t.translate("saved_accounts")),
              Gaps.h12,
              SavedAccountTile(
                title:
                    "${t.translate("login_as")} ${lastName ?? lastEmail!.split('@').first}",
                onTap: loading ? null : handleGoogleLogin,
                onMenu: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}
