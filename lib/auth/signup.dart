import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import '../services/auth_service.dart';
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

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    fullname.dispose();
    password.dispose();
    super.dispose();
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

    // USERNAME LENGTH CHECK
    if (uname.length < 3) {
      _showSnack("Username must be at least 3 characters.");
      return false;
    }

    if (uname.length > 50) {
      _showSnack("Username cannot exceed 50 characters.");
      return false;
    }

    // EMAIL VALIDATION
    if (!emailRegex.hasMatch(mail)) {
      _showSnack("Enter a valid email.");
      return false;
    }

    // PASSWORD LENGTH
    if (pass.length < 6) {
      _showSnack("Password must be at least 6 characters.");
      return false;
    }

    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> signup() async {
    if (!_validateInput()) return;

    setState(() => loading = true);

    final url = Uri.parse("http://10.0.2.2:8000/signup");

    final body = {
      "username": username.text.trim(),
      "email": email.text.trim(),
      "full_name": fullname.text.trim(),
      "password": password.text.trim(),
    };

    try {
      final response = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 10));

      setState(() => loading = false);


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: data["email"] ?? "",
            ),
          ),
        );
      }


      else {
        final decoded = jsonDecode(response.body);
        final msg = decoded["detail"] ?? "Signup failed";
        _showSnack(msg.toString());
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
      final decoded = jsonDecode(result);
      final msg = decoded["message"] ?? "Signed in successfully!";
      _showSnack(msg.toString());
    } catch (_) {
      _showSnack("Google sign-in failed: invalid response.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: username,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: fullname,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),

            TextField(
              controller: password,
              obscureText: !passwordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() {
                    passwordVisible = !passwordVisible;
                  }),
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : signup,
              child: loading
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Text("Create Account"),
            ),

            const SizedBox(height: 20),

            Row(
              children: const [
                Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("or"),
                ),
                Expanded(child: Divider(thickness: 1)),
              ],
            ),

            const SizedBox(height: 20),

            SignInButton(
              Buttons.Google,
              text: "Continue with Google",
              onPressed: handleGoogleSignup,
            ),
          ],
        ),
      ),
    );
  }
}
