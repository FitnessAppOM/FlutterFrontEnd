import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final TextEditingController codeController = TextEditingController();
  bool loading = false;

  bool resendCooldown = false;     // prevent spam
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

    final url = Uri.parse("http://10.0.2.2:8000/verify-email");

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
        Navigator.pop(context);
      } else {
        final msg = jsonDecode(response.body)["detail"];
        _show(msg);
      }
    } catch (e) {
      setState(() => loading = false);
      _show("Error: $e");
    }
  }

  // ---------------- RESEND CODE ----------------
  Future<void> resendCode() async {
    if (resendCooldown) return; // protect from spam clicks

    // enable cooldown
    setState(() {
      resendCooldown = true;
      cooldownSeconds = 30;
    });

    // Start countdown timer
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        cooldownSeconds--;
        if (cooldownSeconds <= 0) {
          resendCooldown = false;
          t.cancel();
        }
      });
    });

    final url = Uri.parse("http://10.0.2.2:8000/resend-code");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        _show("New verification code sent");
      } else {
        final msg = jsonDecode(response.body)["detail"];
        _show(msg);
      }
    } catch (e) {
      _show("Error: $e");
    }
  }

  // ---------------- SHOW SNACK ----------------
  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("A verification code has been sent to:",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(widget.email,
                style: const TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),

            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: "Enter verification code",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : verifyCode,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Verify"),
            ),

            const SizedBox(height: 20),

            Center(
              child: resendCooldown
                  ? Text(
                "Resend available in $cooldownSeconds sec",
                style: const TextStyle(color: Colors.grey),
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
