import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import '../../auth/questionnaire.dart';   // <-- Redirect target

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController pwCtrl = TextEditingController();
  final TextEditingController retypeCtrl = TextEditingController();

  bool loading = false;

  Future<void> resetPassword() async {
    final newPw = pwCtrl.text.trim();
    final rePw = retypeCtrl.text.trim();

    // --------------------------------------
    // 1. Check empty fields
    // --------------------------------------
    if (newPw.isEmpty || rePw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields.")),
      );
      return;
    }

    // --------------------------------------
    // 2. Check if passwords match
    // --------------------------------------
    if (newPw != rePw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/password/reset");

    final body = jsonEncode({
      "email": widget.email,
      "code": widget.code,
      "new_password": newPw,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      // ---------------------------------------------
      // Backend validation
      // ---------------------------------------------
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data?["detail"] ?? "Password reset failed")),
        );
        return;
      }

      // ---------------------------------------------
      // Success
      // ---------------------------------------------
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password changed successfully!")),
      );

      // Redirect to QuestionnairePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuestionnairePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Reset Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
              ),
            ),
            Gaps.h12,

            TextField(
              controller: retypeCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Retype Password",
              ),
            ),

            Gaps.h20,

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : resetPassword,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Reset Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
