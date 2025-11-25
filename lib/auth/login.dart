import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/account_storage.dart';
import '../services/auth_service.dart';
import '../theme/spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';
import 'email_verification_page.dart';
import 'package:taqaproject/screens/ForgetPassword/forgot_password_page.dart';

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
    final mail = email.text.trim();
    final pass = password.text;

    if (mail.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/auth/login");
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
      } catch (_) {
        data = null;
      }

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

        await AccountStorage.saveUserSession(
          userId: userId,
          email: emailFromApi,
          name: name,
          verified: true,
          token: token,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Welcome, $name")));

        return;
      }

      final detail =
      (data?['detail'] ?? response.reasonPhrase ?? 'Login failed').toString();

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
        SnackBar(content: Text("Network error: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleGoogleLogin() async {
    final result = await signInWithGoogle();
    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google sign-in canceled or failed.")),
      );
      return;
    }

    try {
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final msg = decoded["message"] ?? "Signed in successfully!";
      final gEmail = (decoded["email"] ?? "").toString();
      final gName = (decoded["name"] ??
          (gEmail.isNotEmpty ? gEmail.split('@').first : ''))
          .toString();
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google sign-in failed: invalid response.")),
      );
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        !loading && email.text.trim().isNotEmpty && password.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Login"),
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
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "example@gmail.com",
              ),
            ),
            Gaps.h12,
            TextField(
              controller: password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Password",
                hintText: "Your password",
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

                child: const Text("Forgot Password?"),
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
                    : const Text("Login"),
              ),
            ),
            Gaps.h20,
            const DividerWithLabel(label: "or"),
            Gaps.h12,
            SocialButton.apple(
              icon: Icons.apple,
              text: "Sign in with Apple",
              onPressed: () {},
            ),
            Gaps.h12,
            SocialButton.dark(
              iconAsset: null,
              icon: Icons.g_mobiledata,
              text: "Sign in with Google",
              onPressed: handleGoogleLogin,
            ),
            Gaps.h20,
            if (lastVerified && (lastEmail ?? '').isNotEmpty) ...[
              const DividerWithLabel(label: "saved accounts"),
              Gaps.h12,
              SavedAccountTile(
                title: "Log in as ${lastName ?? lastEmail!.split('@').first}",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginPage(prefilledEmail: lastEmail),
                    ),
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
