import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import 'questionnaire.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final TextEditingController codeController = TextEditingController();

  bool loading = false;

  // resend cooldown
  bool resendCooldown = false;
  int cooldownSeconds = 30;
  Timer? timer;

  @override
  void dispose() {
    codeController.dispose();
    timer?.cancel();
    super.dispose();
  }

  // ---------------- VERIFY CODE ----------------
  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      _show("Code must be 6 digits");
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/auth/verify-email");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "code": code,
        }),
      );

      setState(() => loading = false);

      if (response.statusCode == 200) {
        _show("Email verified successfully!");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QuestionnairePage()),
        );
        return;
      }
      else {
        String msg = "Verification failed";
        try {
          msg = (jsonDecode(response.body)["detail"] ?? msg).toString();
        } catch (_) {}
        _show(msg);
      }
    } catch (e) {
      setState(() => loading = false);
      _show("Error: $e");
    }
  }

  // ---------------- RESEND CODE ----------------
  Future<void> resendCode() async {
    if (resendCooldown) return;

    // enable cooldown
    setState(() {
      resendCooldown = true;
      cooldownSeconds = 30;
    });

    // countdown timer
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        cooldownSeconds--;
        if (cooldownSeconds <= 0) {
          resendCooldown = false;
          t.cancel();
        }
      });
    });

    // adjust path if your backend differs
    final url = Uri.parse("http://10.0.2.2:8000/auth/resend-verification");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        _show("New verification code sent");
      } else {
        String msg = "Resend failed";
        try {
          msg = (jsonDecode(response.body)["detail"] ?? msg).toString();
        } catch (_) {}
        _show(msg);
      }
    } catch (e) {
      _show("Error: $e");
    }
  }

  // ---------------- helpers ----------------
  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _obfuscateEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    final visible = name.length <= 2 ? name : "${name.substring(0, 2)}${'*' * (name.length - 2)}";
    return "$visible@$domain";
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !loading && codeController.text.trim().length == 6;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Verify Email"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "A verification code has been sent to:",
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Gaps.h5,
            Text(
              _obfuscateEmail(widget.email),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            Gaps.h20,

            // Code input (underlined style from InputDecorationTheme)
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Enter verification code",
                hintText: "6-digit code",
                counterText: "", // hide maxLength counter
              ),
            ),

            Gaps.h20,

            // Verify button
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: canSubmit ? verifyCode : null,
                child: loading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
                    : const Text("Verify"),
              ),
            ),

            Gaps.h20,

            // Resend code
            Center(
              child: resendCooldown
                  ? Text(
                "Resend available in $cooldownSeconds sec",
                style: const TextStyle(color: Colors.white54),
              )
                  : TextButton(
                onPressed: resendCode,
                child: const Text("Resend code"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
