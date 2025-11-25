import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import 'reset_password_page.dart';

class VerifyResetCodePage extends StatefulWidget {
  final String email;

  const VerifyResetCodePage({required this.email});

  @override
  State<VerifyResetCodePage> createState() => _VerifyResetCodePageState();
}

class _VerifyResetCodePageState extends State<VerifyResetCodePage> {
  final TextEditingController codeCtrl = TextEditingController();

  bool loading = false;

  // -------------------------------
  // COOLDOWN SYSTEM
  // -------------------------------
  bool resendCooldown = false;
  int cooldownSeconds = 30;

  Timer? timer;
  DateTime? cooldownEndsAt; // where cooldown ends

  @override
  void initState() {
    super.initState();
    _restoreCooldown();
  }

  @override
  void dispose() {
    timer?.cancel();
    codeCtrl.dispose();
    super.dispose();
  }

  // -------------------------------
  // Restore countdown if returning to the page
  // -------------------------------
  void _restoreCooldown() {
    if (cooldownEndsAt == null) return;

    final now = DateTime.now();
    final remaining = cooldownEndsAt!.difference(now).inSeconds;

    if (remaining > 0) {
      cooldownSeconds = remaining;
      resendCooldown = true;
      _startTimer();
    } else {
      resendCooldown = false;
    }
  }

  // -------------------------------
  // Start a new cooldown
  // -------------------------------
  void _startCooldown() {
    cooldownEndsAt = DateTime.now().add(Duration(seconds: 30));
    cooldownSeconds = 30;
    resendCooldown = true;

    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final now = DateTime.now();

      if (cooldownEndsAt == null) {
        t.cancel();
        return;
      }

      final remaining = cooldownEndsAt!.difference(now).inSeconds;

      if (remaining <= 0) {
        t.cancel();
        setState(() => resendCooldown = false);
      } else {
        setState(() => cooldownSeconds = remaining);
      }
    });
  }

  // -------------------------------
  // RESEND CODE
  // -------------------------------
  Future<void> resendCode() async {
    if (resendCooldown) return;

    _startCooldown();

    final url = Uri.parse("http://10.0.2.2:8000/password/forgot");
    final body = jsonEncode({"email": widget.email});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reset code resent.")),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["detail"].toString())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }

  // -------------------------------
  // VERIFY CODE
  // -------------------------------
  Future<void> verifyCode() async {
    final code = codeCtrl.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter the reset code.")),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/password/verify");
    final body = jsonEncode({"email": widget.email, "code": code});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ResetPasswordPage(email: widget.email, code: code),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["detail"].toString())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Verify Reset Code"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "A reset code was sent to:",
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              widget.email,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            Gaps.h20,

            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: "Code",
                hintText: "6-digit code",
              ),
            ),

            Gaps.h20,

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : verifyCode,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Verify"),
              ),
            ),

            Gaps.h20,

            Center(
              child: TextButton(
                onPressed: resendCooldown ? null : resendCode,
                child: resendCooldown
                    ? Text(
                  "Resend in ${cooldownSeconds}s",
                  style: const TextStyle(color: Colors.grey),
                )
                    : const Text(
                  "Resend Code",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
