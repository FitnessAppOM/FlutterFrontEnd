import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../services/auth_service.dart';
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

class LoginPage extends StatefulWidget {
  final String? prefilledEmail;
  const LoginPage({super.key, this.prefilledEmail});

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

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      email.text = widget.prefilledEmail!;
    }
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getEmail();
    final n = await AccountStorage.getName();
    final v = await AccountStorage.isVerified();

    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = v ? n : null;
      lastVerified = v;
    });
  }

  Future<void> login() async {
    final t = AppLocalizations.of(context);

    final mail = email.text.trim();
    final pass = password.text;

    if (mail.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("error_required_fields"))),
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

        final emailFromApi = (data?['email'] ?? mail).toString();
        final name = (data?['username'] ??
                data?['full_name'] ??
                emailFromApi.split('@').first)
            .toString();
        final token = data?['token']?.toString();

        // Save session
        await AccountStorage.saveUserSession(
          userId: userId,
          email: emailFromApi,
          name: name,
          verified: true,
          token: token,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t.translate("welcome_user").replaceFirst("{name}", name),
            ),
          ),
        );

        // ------------------------------------------------
        // REDIRECT TO MAIN LAYOUT
        // ------------------------------------------------
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );

        return;
      }

      final detail =
          (data?['detail'] ?? response.reasonPhrase ?? 'Login failed')
              .toString();

      // Email not verified
      if (response.statusCode == 403 &&
          detail.toLowerCase().contains('verify')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail)));

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationPage(email: mail)),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detail)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.translate("network_error")}: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleGoogleLogin() async {
    final t = AppLocalizations.of(context);

    final result = await signInWithGoogle();
    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("google_failed"))),
      );
      return;
    }

    try {
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final gEmail = (decoded["email"] ?? "").toString();
      final gName =
          (decoded["name"] ?? gEmail.split('@').first).toString();
      final token = decoded["token"] as String?;

      final rawId = decoded["user_id"] ?? decoded["id"];
      final int gUserId =
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

      await AccountStorage.saveUserSession(
        userId: gUserId,
        email: gEmail,
        name: gName,
        verified: true,
        token: token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("google_success"))),
      );

      // Redirect to main
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate("google_invalid"))),
      );
    }
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

            if (lastVerified && (lastEmail ?? '').isNotEmpty) ...[
              DividerWithLabel(label: t.translate("saved_accounts")),
              Gaps.h12,
              SavedAccountTile(
                title:
                    "${t.translate("login_as")} ${lastName ?? lastEmail!.split('@').first}",
               onTap: () async {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const MainLayout()),
    (route) => false,
  );
},
                onMenu: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}