import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/profile_service.dart';
import '../main/main_layout.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_text_field.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../localization/app_localizations.dart'; //  ADDED
import 'email_verification_page.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../core/account_storage.dart';
import 'questionnaire.dart';
import 'expert_questionnaire.dart';
import '../services/core/notification_service.dart';
import '../services/core/daily_provider_push_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, this.isExpert = false});

  final bool isExpert;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;
  bool passwordVisible = false;

  // Password guide is shown from the start and auto-hides a few seconds
  // after every rule is satisfied.
  bool _hidePasswordRules = false;
  Timer? _passwordRulesHideTimer;

  final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final RegExp usernameRegex = RegExp(r'^[A-Za-z0-9._-]+$');

  @override
  void dispose() {
    _passwordRulesHideTimer?.cancel();
    username.dispose();
    email.dispose();
    firstName.dispose();
    lastName.dispose();
    password.dispose();
    super.dispose();
  }

  // Drives the live checklist and the delayed auto-hide when all rules pass.
  void _onPasswordChanged() {
    final allMet = _passwordMeetsAllRules(password.text);

    if (allMet) {
      // Schedule a graceful hide once everything is green.
      _passwordRulesHideTimer ??= Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _hidePasswordRules = true);
      });
    } else {
      // Any rule broke again: cancel the hide and bring the guide back.
      _passwordRulesHideTimer?.cancel();
      _passwordRulesHideTimer = null;
      _hidePasswordRules = false;
    }

    setState(() {});
  }

  void _showSnack(String msg, {AppToastType type = AppToastType.error}) {
    if (!mounted) return;
    AppToast.show(context, msg, type: type);
  }

  bool _validateInput() {
    final t = AppLocalizations.of(context);

    final uname = username.text.trim();
    final mail = email.text.trim();
    final pass = password.text.trim();
    final fname = firstName.text.trim();
    final lname = lastName.text.trim();

    if (uname.isEmpty ||
        mail.isEmpty ||
        fname.isEmpty ||
        lname.isEmpty ||
        pass.isEmpty) {
      _showSnack(t.translate("signup_required_fields"));
      return false;
    }
    if (uname.length < 3) {
      _showSnack(t.translate("signup_username_short"));
      return false;
    }
    if (uname.length > 50) {
      _showSnack(t.translate("signup_username_long"));
      return false;
    }
    if (!usernameRegex.hasMatch(uname)) {
      _showSnack(t.translate("signup_username_invalid"));
      return false;
    }
    if (!emailRegex.hasMatch(mail)) {
      _showSnack(t.translate("signup_email_invalid"));
      return false;
    }
    if (pass.length < 8) {
      _showSnack(t.translate("signup_password_short"));
      return false;
    }
    // Mirror the backend policy so users are not rejected after submitting.
    if (!_passwordMeetsAllRules(pass)) {
      _showSnack(t.translate("signup_password_weak"));
      return false;
    }
    return true;
  }

  // ---- Password rule checks (must match backend _validate_password_strong) ----
  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUppercase(String p) => RegExp(r'[A-Z]').hasMatch(p);
  bool _hasLowercase(String p) => RegExp(r'[a-z]').hasMatch(p);
  bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);
  bool _hasSymbol(String p) =>
      RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':",.<>/?\\|`~]''').hasMatch(p);

  bool _passwordMeetsAllRules(String p) =>
      _hasMinLength(p) &&
      _hasUppercase(p) &&
      _hasLowercase(p) &&
      _hasDigit(p) &&
      _hasSymbol(p);

  Future<void> signup() async {
    final t = AppLocalizations.of(context);

    if (!_validateInput()) return;

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/auth/signup");
    final body = jsonEncode({
      "username": username.text.trim(),
      "email": email.text.trim(),
      "first_name": firstName.text.trim(),
      "last_name": lastName.text.trim(),
      "password": password.text.trim(),
    });

    try {
      final response = await http
          .post(url, headers: {"Content-Type": "application/json"}, body: body)
          .timeout(const Duration(seconds: 12));

      setState(() => loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mail = (data["email"] ?? email.text.trim()).toString();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EmailVerificationPage(email: mail, isExpert: widget.isExpert),
          ),
        );
      } else {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}

        final msg =
            (decoded?["detail"] ??
                    response.reasonPhrase ??
                    t.translate("signup_failed"))
                .toString();

        _showSnack(msg);
      }
    } catch (e) {
      setState(() => loading = false);
      _showSnack("${t.translate("network_error")}: $e");
    }
  }

  Future<void> handleGoogleSignup() async {
    final t = AppLocalizations.of(context);

    if (!mounted) return;
    setState(() => loading = true);

    final result = await signInWithGoogle();

    if (!mounted) return;
    setState(() => loading = false);

    if (result == null) {
      _showSnack(t.translate("google_failed"));
      return;
    }

    // Same as Google sign-in: read access_token and user_id from response
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
      _showSnack(t.translate("google_failed"));
      return;
    }

    final email = (result["email"] ?? "").toString();
    final name = (result["name"] ?? email.split('@').first).toString();

    await AccountStorage.saveUserSession(
      userId: userId,
      email: email,
      name: name,
      verified: true,
      token: accessToken,
      isExpert: widget.isExpert,
      questionnaireDone: false,
      expertQuestionnaireDone: false,
      authProvider: "google",
    );
    await AccountStorage.markSkipDailyJournalPromptForNextSession(
      userId: userId,
    );

    final savedId = await AccountStorage.getUserId();
    final savedToken = await AccountStorage.getAccessToken();
    if (savedId == null ||
        savedId <= 0 ||
        savedToken == null ||
        savedToken.isEmpty) {
      if (!mounted) return;
      _showSnack(t.translate("google_failed"));
      return;
    }

    await NotificationService.refreshDailyJournalRemindersForCurrentUser();
    await DailyProviderPushService().pushIfAfterOneAmLocal();

    if (!mounted) return;

    _showSnack(
      t.translate("google_success_message"),
      type: AppToastType.success,
    );

    // Same post-auth flow as Google sign-in: fetch profile, then MainLayout or questionnaire
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final serverDone = profile["filled_user_questionnaire"] == true;
      final expertQuestionnaireDone =
          profile["filled_expert_questionnaire"] == true;
      final hasData = serverDone || _hasQuestionnaireData(profile);
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(expertQuestionnaireDone);
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
            builder: (_) => widget.isExpert
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
          builder: (_) => widget.isExpert
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> handleAppleSignup() async {
    final t = AppLocalizations.of(context);

    if (!mounted) return;
    setState(() => loading = true);

    final result = await signInWithApple();

    if (!mounted) return;
    setState(() => loading = false);

    if (result == null) {
      _showSnack(t.translate("apple_failed"));
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
      _showSnack(t.translate("apple_failed"));
      return;
    }

    final email = (result["email"] ?? "").toString();
    final name = (result["name"] ?? email.split('@').first).toString();

    await AccountStorage.saveUserSession(
      userId: userId,
      email: email,
      name: name,
      verified: true,
      token: accessToken,
      isExpert: widget.isExpert,
      questionnaireDone: false,
      expertQuestionnaireDone: false,
      authProvider: "apple",
    );
    await AccountStorage.markSkipDailyJournalPromptForNextSession(
      userId: userId,
    );

    final savedId = await AccountStorage.getUserId();
    final savedToken = await AccountStorage.getAccessToken();
    if (savedId == null ||
        savedId <= 0 ||
        savedToken == null ||
        savedToken.isEmpty) {
      if (!mounted) return;
      _showSnack(t.translate("apple_failed"));
      return;
    }

    await NotificationService.refreshDailyJournalRemindersForCurrentUser();
    await DailyProviderPushService().pushIfAfterOneAmLocal();

    if (!mounted) return;

    _showSnack(
      t.translate("apple_success_message"),
      type: AppToastType.success,
    );

    // Same post-auth flow as Google sign-in: fetch profile, then MainLayout or questionnaire
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final serverDone = profile["filled_user_questionnaire"] == true;
      final expertQuestionnaireDone =
          profile["filled_expert_questionnaire"] == true;
      final hasData = serverDone || _hasQuestionnaireData(profile);
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(expertQuestionnaireDone);
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
            builder: (_) => widget.isExpert
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
          builder: (_) => widget.isExpert
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

  Widget _buildPasswordRequirements(AppLocalizations t) {
    final pass = password.text;

    final rules = <MapEntry<String, bool>>[
      MapEntry("signup_password_rule_length", _hasMinLength(pass)),
      MapEntry("signup_password_rule_uppercase", _hasUppercase(pass)),
      MapEntry("signup_password_rule_lowercase", _hasLowercase(pass)),
      MapEntry("signup_password_rule_digit", _hasDigit(pass)),
      MapEntry("signup_password_rule_symbol", _hasSymbol(pass)),
    ];

    final card = Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: TaqaUiScale.h(12)),
      padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate("signup_password_requirements_title"),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          for (final rule in rules) ...[
            _buildRuleRow(t.translate(rule.key), rule.value),
            if (rule != rules.last) SizedBox(height: TaqaUiScale.h(6)),
          ],
        ],
      ),
    );

    // Neatly collapse + fade the guide away once everything is green.
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: _hidePasswordRules ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: _hidePasswordRules ? const SizedBox(width: double.infinity) : card,
      ),
    );
  }

  Widget _buildRuleRow(String label, bool satisfied) {
    final color = satisfied
        ? TaqaUiColors.unnamedColor1c1d17
        : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: TaqaUiScale.w(16),
          color: satisfied
              ? TaqaUiColors.unnamedColorE4e93b
              : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.25),
        ),
        SizedBox(width: TaqaUiScale.w(8)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(12),
              fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titleKey = widget.isExpert ? "signup_expert_title" : "signup_title";
    final buttonKey = widget.isExpert ? "signup_expert_btn" : "signup_btn";

    final canSubmit =
        !loading &&
        username.text.trim().isNotEmpty &&
        email.text.trim().isNotEmpty &&
        firstName.text.trim().isNotEmpty &&
        lastName.text.trim().isNotEmpty &&
        password.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t.translate(titleKey),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isExpert) ...[
                  Container(
                    width: double.infinity,
                    padding: TaqaUiScale.insetsLTRB(12, 12, 12, 12),
                    margin: EdgeInsets.only(bottom: TaqaUiScale.h(16)),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.unnamedColorE4e93b.withValues(
                        alpha: 0.25,
                      ),
                      borderRadius: TaqaUiScale.radius(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: TaqaUiColors.unnamedColor1c1d17,
                          size: TaqaUiScale.w(20),
                        ),
                        SizedBox(width: TaqaUiScale.w(10)),
                        Expanded(
                          child: Text(
                            t.translate("signup_expert_note"),
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(12),
                              fontWeight: FontWeight.w400,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Username
                TaqaTextField(
                  controller: username,
                  label: t.translate("signup_username"),
                  hint: t.translate("signup_username_hint"),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: TaqaUiScale.h(12)),

                // Email
                TaqaTextField(
                  controller: email,
                  label: t.translate("email"),
                  hint: t.translate("email_hint"),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: TaqaUiScale.h(12)),

                // First name
                TaqaTextField(
                  controller: firstName,
                  label: t.translate("signup_first_name"),
                  hint: t.translate("signup_first_name_hint"),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: TaqaUiScale.h(12)),

                // Last name
                TaqaTextField(
                  controller: lastName,
                  label: t.translate("signup_last_name"),
                  hint: t.translate("signup_last_name_hint"),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: TaqaUiScale.h(12)),

                // Password
                TaqaTextField(
                  controller: password,
                  label: t.translate("password"),
                  hint: t.translate("password_hint"),
                  obscureText: !passwordVisible,
                  onChanged: (_) => _onPasswordChanged(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                      size: TaqaUiScale.w(20),
                    ),
                    onPressed: () =>
                        setState(() => passwordVisible = !passwordVisible),
                  ),
                ),

                // Password requirements checklist
                _buildPasswordRequirements(t),

                // Signup button
                SizedBox(height: TaqaUiScale.h(20)),
                TaqaFilledButton(
                  label: t.translate(buttonKey),
                  loading: loading,
                  onTap: canSubmit ? signup : null,
                ),

                // OR divider
                SizedBox(height: TaqaUiScale.h(20)),
                DividerWithLabel(label: t.translate("or")),
                SizedBox(height: TaqaUiScale.h(12)),

                // Apple
                if (Platform.isIOS) ...[
                  SocialButton.apple(
                    icon: Icons.apple,
                    text: t.translate("apple_login"),
                    onPressed: handleAppleSignup,
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                ],

                // Google
                SocialButton.dark(
                  icon: Icons.g_mobiledata,
                  text: t.translate("google_signup"),
                  onPressed: handleGoogleSignup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
