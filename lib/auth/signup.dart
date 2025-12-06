import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../localization/app_localizations.dart';   //  ADDED
import 'email_verification_page.dart';
import '../widgets/app_toast.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, this.isExpert = false});

  final bool isExpert;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController fullname = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;
  bool passwordVisible = false;

  final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final RegExp usernameRegex = RegExp(r'^[A-Za-z0-9._-]+$');

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    fullname.dispose();
    password.dispose();
    super.dispose();
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
    final fname = fullname.text.trim();

    if (uname.isEmpty || mail.isEmpty || fname.isEmpty || pass.isEmpty) {
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
    return true;
  }

  Future<void> signup() async {
    final t = AppLocalizations.of(context);

    if (!_validateInput()) return;

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/auth/signup");
    final body = jsonEncode({
      "username": username.text.trim(),
      "email": email.text.trim(),
      "full_name": fullname.text.trim(),
      "password": password.text.trim(),
    });

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      setState(() => loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final mail = (data["email"] ?? email.text.trim()).toString();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: mail,
              isExpert: widget.isExpert,
            ),
          ),
        );
      } else {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}

        final msg = (decoded?["detail"] ??
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

    final result = await signInWithGoogle();
    if (result == null) {
      _showSnack(t.translate("google_failed"));
      return;
    }

    try {
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final msg = decoded["message"] ?? t.translate("google_success");
      _showSnack(msg.toString());
    } catch (_) {
      _showSnack(t.translate("google_invalid"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titleKey = widget.isExpert ? "signup_expert_title" : "signup_title";
    final buttonKey = widget.isExpert ? "signup_expert_btn" : "signup_btn";

    final canSubmit = !loading &&
        username.text.trim().isNotEmpty &&
        email.text.trim().isNotEmpty &&
        fullname.text.trim().isNotEmpty &&
        password.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate(titleKey)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (widget.isExpert) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.workspace_premium, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.translate("signup_expert_note"),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.white,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Username
            TextField(
              controller: username,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.translate("signup_username"),
                hintText: t.translate("signup_username_hint"),
              ),
            ),
            Gaps.h12,

            // Email
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

            // Full name
            TextField(
              controller: fullname,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.translate("signup_fullname"),
                hintText: t.translate("signup_fullname_hint"),
              ),
            ),
            Gaps.h12,

            // Password
            TextField(
              controller: password,
              obscureText: !passwordVisible,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: t.translate("password"),
                hintText: t.translate("password_hint"),
                suffixIcon: IconButton(
                  icon: Icon(
                      passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => passwordVisible = !passwordVisible),
                ),
              ),
            ),

            // Signup button
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: canSubmit ? signup : null,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : Text(t.translate(buttonKey)),
              ),
            ),

            // OR divider
            Gaps.h20,
            DividerWithLabel(label: t.translate("or")),
            Gaps.h12,

            // Apple
            SocialButton.apple(
              icon: Icons.apple,
              text: t.translate("apple_login"),
              onPressed: () {},
            ),
            Gaps.h12,

            // Google
            SocialButton.dark(
              icon: Icons.g_mobiledata,
              text: t.translate("google_signup"),
              onPressed: handleGoogleSignup,
            ),
          ],
        ),
      ),
    );
  }
}
