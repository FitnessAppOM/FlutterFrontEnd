import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart'; // signInWithGoogle()
import '../core/account_storage.dart';
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import 'email_verification_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validateInput() {
    final uname = username.text.trim();
    final mail = email.text.trim();
    final pass = password.text.trim();
    final fname = fullname.text.trim();

    if (uname.isEmpty || mail.isEmpty || fname.isEmpty || pass.isEmpty) {
      _showSnack("All fields are required.");
      return false;
    }
    if (uname.length < 3) {
      _showSnack("Username must be at least 3 characters.");
      return false;
    }
    if (uname.length > 50) {
      _showSnack("Username cannot exceed 50 characters.");
      return false;
    }
    if (!usernameRegex.hasMatch(uname)) {
      _showSnack("Username can use letters, numbers, '.', '-' or '_'.");
      return false;
    }
    if (!emailRegex.hasMatch(mail)) {
      _showSnack("Enter a valid email.");
      return false;
    }
    if (pass.length < 8) {
      _showSnack("Password must be at least 8 characters.");
      return false;
    }
    return true;
  }

  Future<void> signup() async {
    if (!_validateInput()) return;

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/auth/signup");
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
        final name = fullname.text.trim().isNotEmpty
            ? fullname.text.trim()
            : username.text.trim();

        await AccountStorage.saveLastUser(email: mail, name: name);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationPage(email: mail)),
        );
      } else {
        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        final msg =
        (decoded?["detail"] ?? response.reasonPhrase ?? "Signup failed").toString();
        _showSnack(msg);
      }
    } catch (e) {
      setState(() => loading = false);
      _showSnack("Network error: $e");
    }
  }

  Future<void> handleGoogleSignup() async {
    final result = await signInWithGoogle();
    if (result == null) {
      _showSnack("Google sign-in canceled or failed.");
      return;
    }

    try {
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final msg = decoded["message"] ?? "Signed in successfully!";
      final gEmail = (decoded["email"] ?? "").toString();
      final gName =
      (decoded["name"] ?? (gEmail.isNotEmpty ? gEmail.split('@').first : '')).toString();

      await AccountStorage.saveLastUser(email: gEmail, name: gName);
      _showSnack(msg.toString());

      // If your backend auto-verifies Google users, you can navigate to Home here.
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (_) {
      _showSnack("Google sign-in failed: invalid response.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !loading &&
        username.text.trim().isNotEmpty &&
        email.text.trim().isNotEmpty &&
        fullname.text.trim().isNotEmpty &&
        password.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Sign Up"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Username
            TextField(
              controller: username,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Username",
                hintText: "yourname_123",
              ),
            ),
            Gaps.h12,

            // Email
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

            // Full name
            TextField(
              controller: fullname,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Full Name",
                hintText: "First Last",
              ),
            ),
            Gaps.h12,

            // Password (with visibility toggle)
            TextField(
              controller: password,
              obscureText: !passwordVisible,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "Password",
                hintText: "minimum 8 characters",
                suffixIcon: IconButton(
                  icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => passwordVisible = !passwordVisible),
                ),
              ),
            ),

            // Create Account button
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: canSubmit ? signup : null,
                child: loading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                )
                    : const Text("Create Account"),
              ),
            ),

            // OR divider
            Gaps.h20,
            const DividerWithLabel(label: "or"),
            Gaps.h12,

            // Apple (iOS only)
            SocialButton.apple(
              icon: Icons.apple,
              text: "Continue with Apple",
              onPressed: () {},
            ),
            Gaps.h12,

            // Google sign up (dark pill)
            SocialButton.dark(
              icon: Icons.g_mobiledata, // swap to your Google asset if you like
              text: "Continue with Google",
              onPressed: handleGoogleSignup,
            ),
          ],
        ),
      ),
    );
  }
}
