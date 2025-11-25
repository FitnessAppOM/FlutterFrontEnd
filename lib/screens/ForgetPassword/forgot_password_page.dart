import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import 'verify_reset_code_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  bool loading = false;

  Future<void> sendResetCode() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your email.")),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/password/forgot");
    final body = jsonEncode({"email": email});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        // ---------------------------------------
        // Show success: code sent to user's email
        // ---------------------------------------
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Reset code sent to $email")),
        );

        // ---------------------------------------
        // IMPORTANT FIX:
        // Use pushReplacement() to avoid duplicates
        // ---------------------------------------
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyResetCodePage(email: email),
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
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Forgot Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "example@gmail.com",
              ),
            ),
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : sendResetCode,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Send Reset Code"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
