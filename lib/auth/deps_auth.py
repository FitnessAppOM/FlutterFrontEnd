Skip to content
Unable to charge payment method for your Plus subscription
We're keeping your access active for now. To continue using Plus, please update your payment details by Nov 27, 2025.

Update

Chat history

You said:
you have my style files

import 'package:flutter/material.dart';
import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(), // push content to bottom

              // Bottom content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline
                  Text(
                    'Log your workouts easily, all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Button 1: Continue as last user (only if we have a saved account)
                  if (hasAccount) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE9E9E9),
                            ),
                            child: const Icon(Icons.person, size: 18, color: Colors.black87),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Log in as $displayName',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.more_vert, size: 20, color: Colors.black87),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Button 2: Login (generic) or "Login using another account" when we have a saved user
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasAccount ? 'Log in using another account' : 'Log in',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // New to TAQA? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New to TAQA? ', style: TextStyle(color: Colors.white70)),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

modify this to use them,
and if you want to add customization do that i nfiles, better than adding customizing here,
send full code
ChatGPT said:

Thought for 28s
Got it—here’s a cleaned-up welcome.dart that plugs into your style files (app_theme.dart, spacing.dart, primary_button.dart) and keeps customizations inside those files (no ad-hoc styling here other than essential text alignment).

import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';

// style system
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Bottom content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline
                  Text(
                    'Log your workouts easily, all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Gaps.h24,

                  // Button 1: Continue as last user (only if we have a saved account)
                  if (hasAccount) ...[
                    PrimaryWhiteButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.chipGrey,
                            ),
                            child: const Icon(Icons.person, size: 18, color: Colors.black87),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Log in as $displayName',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.more_vert, size: 20, color: Colors.black87),
                        ],
                      ),
                    ),
                    Gaps.h12,
                  ],

                  // Button 2: Login (generic) OR "Login using another account"
                  PrimaryWhiteButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasAccount ? 'Log in using another account' : 'Log in',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Gaps.h20,

                  // New to TAQA? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to TAQA? ',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Notes
Uses your shared spacing (Gaps.h12/h20/h24) instead of raw SizedBox.

Uses your PrimaryWhiteButton for both actions. Any button styling (rounded corners, padding, elevation) should live in your ElevatedButtonTheme inside app_theme.dart. If you want the “white pill” style, set it there; I avoided hard-coding styles here per your request.

Colors come from AppColors (e.g., background, accent, text dim, chip grey).

If your actual folder names differ, just adjust the three imports:

../theme/app_theme.dart

../theme/spacing.dart

../widgets/primary_button.dart

If you want me to also tweak PrimaryWhiteButton or the ElevatedButtonTheme in app_theme.dart to match the exact pill/outline styles you showed earlier, say the word and I’ll update those files only (keeping this screen clean).

You said:
PS C:\Users\omar_\AndroidStudioProjects\taqaproject> flutter run
Launching lib\main.dart on sdk gphone64 x86 64 in debug mode...
lib/screens/welcome.dart:10:8: Error: Error when reading 'lib/widgets/primary_button.dart': The system cannot find the path specified.

import '../widgets/primary_button.dart';
       ^
lib/screens/welcome.dart:74:21: Error: The method 'PrimaryWhiteButton' isn't defined for the type '_WelcomePageState'.
 - '_WelcomePageState' is from 'package:taqaproject/screens/welcome.dart' ('lib/screens/welcome.dart').
Try correcting the name to the name of an existing method, or defining a method named 'PrimaryWhiteButton'.
                    PrimaryWhiteButton(
                    ^^^^^^^^^^^^^^^^^^
lib/screens/welcome.dart:112:19: Error: The method 'PrimaryWhiteButton' isn't defined for the type '_WelcomePageState'.
 - '_WelcomePageState' is from 'package:taqaproject/screens/welcome.dart' ('lib/screens/welcome.dart').
Try correcting the name to the name of an existing method, or defining a method named 'PrimaryWhiteButton'.
                  PrimaryWhiteButton(
                  ^^^^^^^^^^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildDebug'.
> Process 'command 'C:\Users\omar_\AndroidStudioProjects\TAQA_TOOLS\flutter_windows_3.38.1-stable\flutter\bin\flutter.bat'' finished with non-zero exit value 1                                                                                                                                       

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 4s
Running Gradle task 'assembleDebug'...                              4.5s
Error: Gradle task assembleDebug failed with exit code 1
PS C:\Users\omar_\AndroidStudioProjects\taqaproject> 
ChatGPT said:

Thought for 17s
You’re missing the styled button file and (likely) the theme files on the right paths. Drop these 3 files into your project, then use the updated welcome.dart below.

File layout (put them exactly here)
lib/
 ├─ screens/
 │   └─ welcome.dart        ← replace with the one below
 ├─ theme/
 │   ├─ app_theme.dart
 │   └─ spacing.dart
 └─ widgets/
     └─ primary_button.dart
lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const black = Colors.black;
  static const white = Colors.white;
  static const accent = Colors.blue;      // Brand accent (edit if needed)
  static const textDim = Colors.white70;
  static const chipGrey = Color(0xFFE9E9E9);
}

class AppRadii {
  static const pill = 14.0;
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.black,

    // Global ElevatedButton style (used by PrimaryWhiteButton)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.white),
        foregroundColor: WidgetStateProperty.all(Colors.black),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            side: const BorderSide(color: Colors.black12),
          ),
        ),
        textStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(fontWeight: FontWeight.w600, fontSize: 16);
        }),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

ThemeData buildLightTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.white,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.accent),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        textStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(fontWeight: FontWeight.w600, fontSize: 16);
        }),
      ),
    ),
  );
}

/// Optional helper if you want to switch themes from one place
class AppTheme {
  static ThemeData dark() => buildDarkTheme();
  static ThemeData light() => buildLightTheme();
}
lib/theme/spacing.dart
import 'package:flutter/widgets.dart';

class Gaps {
  static const h12 = SizedBox(height: 12);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
}
lib/widgets/primary_button.dart
import 'package:flutter/material.dart';

/// Simple wrapper that relies on the global ElevatedButtonTheme (in app_theme.dart).
/// Keep styling centralized in the theme.
class PrimaryWhiteButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const PrimaryWhiteButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}
lib/screens/welcome.dart (updated to use your style files)
import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';

// style system
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Bottom content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline
                  Text(
                    'Log your workouts easily, all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Gaps.h24,

                  // Button 1: Continue as last user (only if we have a saved account)
                  if (hasAccount) ...[
                    PrimaryWhiteButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.chipGrey,
                            ),
                            child: const Icon(Icons.person, size: 18, color: Colors.black87),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Log in as $displayName',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.more_vert, size: 20, color: Colors.black87),
                        ],
                      ),
                    ),
                    Gaps.h12,
                  ],

                  // Button 2: Login (generic) or "Login using another account"
                  PrimaryWhiteButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasAccount ? 'Log in using another account' : 'Log in',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Gaps.h20,

                  // New to TAQA? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to TAQA? ',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Why the build failed
The error shows lib/widgets/primary_button.dart didn’t exist, so the import failed.

I’ve provided a minimal PrimaryWhiteButton and a proper app_theme.dart (without invalid placeholders) so your AppColors usage compiles.

Final step
Move the files to the paths above.

If your main.dart sets a theme, point it to the dark theme:

return MaterialApp(
  title: 'TAQA Fitness',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(), // from app_theme.dart
  home: const WelcomePage(),
);
Run flutter clean && flutter pub get, then flutter run.

You said:
Uploaded image
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_signin_button/flutter_signin_button.dart';

import '../services/auth_service.dart'; // signInWithGoogle()
import '../core/account_storage.dart';
import 'email_verification_page.dart';   // make sure this file exists
// import '../home/home_page.dart';     // TODO: create your HomePage and import it

class LoginPage extends StatefulWidget {
  final String? prefilledEmail; // allow "continue as ..." to prefill
  const LoginPage({super.key, this.prefilledEmail});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      email.text = widget.prefilledEmail!;
    }
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
        final uid = data?['user_id'] ?? 'unknown';

        await AccountStorage.saveLastUser(
          email: mail,
          name: (data?['username'] ?? data?['full_name'] ?? mail.split('@').first).toString(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome! UserID: $uid")),
        );

        // TODO: navigate to your real home page
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      }

      // If backend blocks unverified users with 403 + "verify" message
      final detail = (data?['detail'] ?? response.reasonPhrase ?? 'Login failed').toString();
      if (response.statusCode == 403 &&
          detail.toLowerCase().contains('verify')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
        // Push verification screen with the email
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationPage(email: mail)),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
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
      final gName  = (decoded["name"]  ?? (gEmail.isNotEmpty ? gEmail.split('@').first : '')).toString();

      await AccountStorage.saveLastUser(email: gEmail, name: gName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));

      // TODO: navigate to your real home page
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
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
    final canSubmit = !loading && email.text.trim().isNotEmpty && password.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}), // updates canSubmit state
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? login : null,
                child: loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("Log In"),
              ),
            ),

            const SizedBox(height: 20),

            // --- OR divider ---
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

            // Google sign-in button
            SignInButton(
              Buttons.Google,
              text: "Continue with Google",
              onPressed: handleGoogleLogin,
            ),
          ],
        ),
      ),
    );
  }
}

make this something sismiar to
the image , again if you wana add themes and styles add style files
ChatGPT said:

Thought for 11s
Nice—let’s match that screen exactly but keep styling centralized. I’ll give you a drop-in login.dart plus a few tiny reusable widgets. Put the files in these paths (same style philosophy as before):

lib/
 ├─ screens/
 │   └─ login.dart          ← replace with this
 ├─ theme/
 │   ├─ app_theme.dart      ← updated: adds input + divider styles
 │   └─ spacing.dart        ← same as before
 └─ widgets/
     ├─ primary_button.dart ← same minimal one we added
     ├─ social_button.dart  ← NEW (Apple/Google/Facebook rows)
     ├─ divider_with_label.dart ← NEW (— or — / “saved accounts”)
     └─ saved_account_tile.dart ← NEW (avatar + “Log in as …” row)
If you want the exact image for reference, it’s here: /mnt/data/86a4dc77-67fe-4908-8d68-82e38dd9fa45.png.

lib/screens/login.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/account_storage.dart';
import '../services/auth_service.dart'; // signInWithGoogle()
import '../theme/spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';
import 'email_verification_page.dart';
// import '../home/home_page.dart'; // TODO: your real home page

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

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      email.text = widget.prefilledEmail!;
    }
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
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
        final uid = data?['user_id'] ?? 'unknown';
        await AccountStorage.saveLastUser(
          email: mail,
          name: (data?['username'] ?? data?['full_name'] ?? mail.split('@').first).toString(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome! UserID: $uid")),
        );
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      }

      final detail = (data?['detail'] ?? response.reasonPhrase ?? 'Login failed').toString();
      if (response.statusCode == 403 && detail.toLowerCase().contains('verify')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmailVerificationPage(email: mail)),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail)));
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
      final gName  = (decoded["name"]  ?? (gEmail.isNotEmpty ? gEmail.split('@').first : '')).toString();

      await AccountStorage.saveLastUser(email: gEmail, name: gName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
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
    final canSubmit = !loading && email.text.trim().isNotEmpty && password.text.isNotEmpty;

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
            // Email
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Email or username",
                hintText: "example@gmail.com",
              ),
            ),
            Gaps.h12,
            // Password
            TextField(
              controller: password,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Password",
                hintText: "minimum 6 characters",
              ),
            ),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: push ForgotPassword page
                },
                child: const Text("Forgot Password?"),
              ),
            ),

            // Login button (disabled when not ready)
            SizedBox(
              width: double.infinity,
              child: PrimaryWhiteButton(
                onPressed: canSubmit ? login : null,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text("Login"),
              ),
            ),

            Gaps.h20,
            const DividerWithLabel(label: "or"),
            Gaps.h12,

            // Social buttons
            SocialButton.dark(
              icon: Icons.apple, // close enough for UI; swap if you use a custom Apple icon
              text: "Sign in with Apple",
              onPressed: () {
                // TODO: implement Sign in with Apple
              },
            ),
            Gaps.h12,
            SocialButton.dark(
              iconAsset: null,
              icon: Icons.g_mobiledata, // or use your Google asset if you prefer
              text: "Sign in with Google",
              onPressed: handleGoogleLogin,
            ),
            Gaps.h12,
            SocialButton.dark(
              icon: Icons.facebook,
              text: "Sign in with Facebook",
              onPressed: () {
                // TODO: implement Facebook login
              },
            ),

            Gaps.h20,
            const DividerWithLabel(label: "saved accounts"),
            Gaps.h12,

            if ((lastEmail ?? '').isNotEmpty)
              SavedAccountTile(
                title: "Log in as ${lastName ?? lastEmail!.split('@').first}",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage(prefilledEmail: lastEmail)),
                  );
                },
                onMenu: () {
                  // TODO: show menu (remove saved, switch, etc.)
                },
              ),
          ],
        ),
      ),
    );
  }
}
lib/theme/app_theme.dart (updated)
import 'package:flutter/material.dart';

class AppColors {
  static const black = Colors.black;
  static const white = Colors.white;
  static const accent = Colors.blue;
  static const textDim = Colors.white70;
  static const chipGrey = Color(0xFFE9E9E9);
  static const surfaceDark = Color(0xFF1E1E1E); // cards/buttons on dark
  static const dividerDark = Color(0xFF2A2A2A);
}

class AppRadii {
  static const pill = 14.0;
  static const tile = 12.0;
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.black,

    // Inputs
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white38),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.dividerDark),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),

    dividerColor: AppColors.dividerDark,

    // Primary button (used by PrimaryWhiteButton wrapper)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF3A3A3A); // greyed when disabled
          }
          return AppColors.white;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.black),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildLightTheme() {
  final base = ThemeData.light();

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.white,
  );
}

class AppTheme {
  static ThemeData dark() => buildDarkTheme();
  static ThemeData light() => buildLightTheme();
}
lib/widgets/social_button.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? iconAsset;

  const SocialButton._({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.iconAsset,
  });

  factory SocialButton.dark({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    String? iconAsset,
  }) {
    return SocialButton._(
      text: text,
      onPressed: onPressed,
      icon: icon,
      iconAsset: iconAsset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (iconAsset != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.asset(iconAsset!, width: 20, height: 20),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.surfaceDark),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          elevation: WidgetStateProperty.all(0),
        ),
        onPressed: onPressed,
        child: content,
      ),
    );
  }
}
lib/widgets/divider_with_label.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DividerWithLabel extends StatelessWidget {
  final String label;
  const DividerWithLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1, color: AppColors.dividerDark)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        const Expanded(child: Divider(thickness: 1, color: AppColors.dividerDark)),
      ],
    );
    }
}
lib/widgets/saved_account_tile.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SavedAccountTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const SavedAccountTile({
    super.key,
    required this.title,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFCCCCCC),
                ),
                child: const Icon(Icons.person, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
lib/widgets/primary_button.dart (unchanged from earlier)
import 'package:flutter/material.dart';

class PrimaryWhiteButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const PrimaryWhiteButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, child: child);
  }
}
lib/theme/spacing.dart (unchanged)
import 'package:flutter/widgets.dart';

class Gaps {
  static const h12 = SizedBox(height: 12);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
}
Hook up the theme (in main.dart)
return MaterialApp(
  title: 'TAQA Fitness',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.dark(),
  home: const LoginPage(),
);
That will produce a screen like the image: dark background, underlined inputs with light labels/hints, greyed disabled Login, “Forgot Password?”, divider “or”, three dark social buttons, another divider “saved accounts”, and a saved account pill with avatar, title, and overflow menu.

You said:
import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';

// style system
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Bottom content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline
                  Text(
                    'Log your workouts easily, all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Gaps.h24,

                  // Button 1: Continue as last user (only if we have a saved account)
                  if (hasAccount) ...[
                    PrimaryWhiteButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.chipGrey,
                            ),
                            child: const Icon(Icons.person, size: 18, color: Colors.black87),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Log in as $displayName',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.more_vert, size: 20, color: Colors.black87),
                        ],
                      ),
                    ),
                    Gaps.h12,
                  ],

                  // Button 2: Login (generic) or "Login using another account"
                  PrimaryWhiteButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasAccount ? 'Log in using another account' : 'Log in',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Gaps.h20,

                  // New to TAQA? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to TAQA? ',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

reuse anystyles from new ones here ?
ChatGPT said:

Thought for 5s
Yep—let’s reuse the shared widgets you just added for Login:

Use SavedAccountTile for the “Log in as …” row (matches your login screen).

Optionally use DividerWithLabel("saved accounts") to keep the section label consistent.

Keep PrimaryWhiteButton for the main CTA (“Log in” / “Log in using another account”).

Keep colors/spacing from AppColors/Gaps.

Here’s a drop-in welcome.dart that does exactly that.

import 'package:flutter/material.dart';

import '../auth/login.dart';
import '../auth/signup.dart';
import '../core/account_storage.dart';

// style system
import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/saved_account_tile.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? lastEmail;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final e = await AccountStorage.getLastEmail();
    final n = await AccountStorage.getLastName();
    if (!mounted) return;
    setState(() {
      lastEmail = e;
      lastName = n;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccount = (lastEmail != null && lastEmail!.isNotEmpty);
    final displayName = lastName ?? (lastEmail?.split('@').first ?? '');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Bottom content
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline
                  Text(
                    'Log your workouts easily, all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  Gaps.h24,

                  // Saved account (consistent with login screen)
                  if (hasAccount) ...[
                    const DividerWithLabel(label: "saved accounts"),
                    Gaps.h12,
                    SavedAccountTile(
                      title: 'Log in as $displayName',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginPage(prefilledEmail: lastEmail),
                          ),
                        );
                      },
                      onMenu: () {
                        // TODO: show menu (remove saved account, switch, etc.)
                      },
                    ),
                    Gaps.h20,
                  ],

                  // Main CTA: Login (generic) or "Login using another account"
                  PrimaryWhiteButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      hasAccount ? 'Log in using another account' : 'Log in',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Gaps.h20,

                  // New to TAQA? Sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to TAQA? ',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignupPage()),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
This keeps the Welcome screen visually aligned with the Login screen by reusing SavedAccountTile and DividerWithLabel, and leaves all styling in your shared theme/widgets.

You said:
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_signin_button/flutter_signin_button.dart';

import '../services/auth_service.dart'; // signInWithGoogle()
import '../core/account_storage.dart';
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

        // Save last user locally for “Continue as …”
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

      // If you want to skip verification for Google (backend marks verified),
      // navigate to Home here. Otherwise, leave as-is.
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
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: username,
              decoration: const InputDecoration(labelText: "Username"),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: fullname,
              decoration: const InputDecoration(labelText: "Full Name"),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: password,
              obscureText: !passwordVisible,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => passwordVisible = !passwordVisible),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? signup : null,
                child: loading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("Create Account"),
              ),
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

also work this out and send full
ChatGPT said:

Thought for a few seconds
Perfect—here’s a drop-in signup.dart that matches the dark UI you’re using on Login (underlined inputs, white primary CTA, “or” divider, dark social button). It reuses the shared styles and widgets (AppColors, Gaps, PrimaryWhiteButton, SocialButton, DividerWithLabel).

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
    final theme = Theme.of(context);

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
Notes
Inputs use your global InputDecorationTheme (dark, underlined) from app_theme.dart.

Primary CTA uses PrimaryWhiteButton so its disabled state and padding match Login.

Social button uses the same SocialButton.dark as Login for visual consistency.

Spacing via Gaps to keep rhythm identical across screens.

If you want Apple/Facebook here too, just add two more SocialButton.dark(...) lines like in Login.

You said:
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

also here 
ChatGPT said:

Thought for 6s
Here’s a styled, drop-in email_verification_page.dart that reuses your shared theme and widgets (AppColors, Gaps, PrimaryWhiteButton) and keeps all customization out of the screen code.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../theme/spacing.dart';
import '../widgets/primary_button.dart';

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
        Navigator.pop(context);
      } else {
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
Uses your styles:

Dark background & underlined inputs via AppTheme (no inline styling).

Spacing via Gaps.

Primary CTA via PrimaryWhiteButton (disabled state + padding consistent with Login/Signup).

If your resend endpoint is different, just change the URL in resendCode() to your actual route.

You said:
dont consider the email and username are occupied or existing if they are not already verified, so if user goes back by mistake to welcome , its fine to reuse mail and verify

from app.utils.validators import sanitize_non_empty, EMAIL_REGEX, USERNAME_REGEX
from app.utils.email_sender import send_verification_email
from app.schemas.user_schemas import UserCreate, UserLogin
from app.database import get_connection
from fastapi import HTTPException
from datetime import datetime, timedelta
import random
import re
import hashlib  # <-- plain hashing

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

# GOOGLE CLIENT ID
CLIENT_ID = "547065160142-m809lbb6qc4s7u6eohqbf77b32nld9q4.apps.googleusercontent.com"

# -------------------------------
# Helpers
# -------------------------------

def _now_utc_naive() -> datetime:
    """UTC now() without tzinfo to fit TIMESTAMP WITHOUT TIME ZONE columns."""
    return datetime.utcnow()

def _normalize_email(email: str) -> str:
    return email.strip().lower()

def _validate_password_strong(pw: str) -> None:
    """
    Strong policy:
      - >= 8 chars
      - at least one lowercase, one uppercase, one digit, one symbol
    """
    if len(pw) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters long")
    if not any(c.islower() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a lowercase letter")
    if not any(c.isupper() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include an uppercase letter")
    if not any(c.isdigit() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a digit")
    symbols = "!@#$%^&*()_+-=[]{};':\",.<>/?\\|~"
    if not any(c in symbols for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a symbol")

def _ensure_unique_username(cur, base_username: str) -> str:
    """If the preferred username is taken, append digits until unique."""
    candidate = base_username
    suffix = 0
    while True:
        cur.execute("SELECT 1 FROM users WHERE username = %s", (candidate,))
        if not cur.fetchone():
            return candidate
        suffix += 1
        candidate = f"{base_username}{suffix}"

# -------------------------------
# SIGNUP
# -------------------------------
def signup_user(user: UserCreate):
    conn = get_connection()
    try:
        cur = conn.cursor()

        # 1) Validate fields
        username = sanitize_non_empty(user.username, "Username", 50).strip()
        email = _normalize_email(sanitize_non_empty(user.email, "Email", 255))
        full_name = sanitize_non_empty(user.full_name, "Full name", 100).strip()

        if not USERNAME_REGEX.match(username):
            raise HTTPException(
                status_code=400,
                detail="Username can only contain letters, numbers, '.', '-' and '_'",
            )

        if not EMAIL_REGEX.match(email):
            raise HTTPException(status_code=400, detail="Invalid email address")

        if not user.password or not user.password.strip():
            raise HTTPException(status_code=400, detail="Password is required")

        password = user.password.strip()
        _validate_password_strong(password)

        # 2) Check duplicates
        cur.execute("SELECT 1 FROM users WHERE email = %s", (email,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Email already exists")

        cur.execute("SELECT 1 FROM users WHERE username = %s", (username,))
        if cur.fetchone():
            username = _ensure_unique_username(cur, username)

        # 3) Hash password (PLAIN SHA-256 HEX)
        password_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()

        # 4) Create verification code (6-digit), 10 min expiry
        code = f"{random.randint(100000, 999999)}"
        expires_at = _now_utc_naive() + timedelta(minutes=10)

        # 5) Insert user
        cur.execute(
            """
            INSERT INTO users 
            (username, email, password_hash, full_name, created_at, updated_at, 
             provider, is_verified, verification_code, verification_expires)
            VALUES (%s, %s, %s, %s, %s, %s, %s, FALSE, %s, %s)
            RETURNING id
            """,
            (
                username,
                email,
                password_hash,
                full_name,
                _now_utc_naive(),
                _now_utc_naive(),
                "local",
                code,
                expires_at,
            ),
        )

        user_id = cur.fetchone()[0]
        conn.commit()

        # 6) Send verification email
        send_verification_email(email, code)

        return {"message": "Verification code sent", "email": email, "user_id": user_id}

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# LOGIN
# -------------------------------
def login_user(credentials: UserLogin):
    conn = get_connection()
    try:
        cur = conn.cursor()

        email = _normalize_email(credentials.email)

        cur.execute(
            "SELECT id, email, password_hash, provider, is_verified FROM users WHERE email = %s",
            (email,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        user_id, _email, stored_hash, provider, is_verified = row

        if provider == "google":
            raise HTTPException(
                status_code=400,
                detail="This account uses Google Sign-In. Please login with Google.",
            )

        if not is_verified:
            raise HTTPException(
                status_code=403,
                detail="Email not verified. Please verify your account.",
            )

        if not stored_hash:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        # SHA-256 verify
        input_hash = hashlib.sha256(credentials.password.encode("utf-8")).hexdigest()
        if stored_hash != input_hash:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        return {"message": "Login successful", "user_id": user_id, "provider": provider}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# VERIFY EMAIL CODE
# -------------------------------
def verify_email_code(payload: dict):
    email = payload.get("email")
    code = payload.get("code")

    if not email or not code:
        raise HTTPException(status_code=400, detail="Email and code required")

    email = _normalize_email(email)

    conn = get_connection()
    try:
        cur = conn.cursor()

        cur.execute("""
            SELECT id, verification_code, verification_expires, is_verified
            FROM users WHERE email = %s
        """, (email,))
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=400, detail="Email not found")

        user_id, stored_code, expires_at, is_verified = row
        now = _now_utc_naive()

        if is_verified and stored_code is None and expires_at is None:
            return {"message": "Email already verified"}

        if not stored_code or not expires_at or now > expires_at:
            raise HTTPException(status_code=400, detail="Verification code expired")

        if stored_code != code:
            raise HTTPException(status_code=400, detail="Invalid verification code")

        cur.execute("""
            UPDATE users 
            SET is_verified = TRUE, 
                verification_code = NULL, 
                verification_expires = NULL,
                updated_at = %s
            WHERE id = %s
        """, (_now_utc_naive(), user_id))
        conn.commit()

        return {"message": "Email verified successfully"}

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# RESEND CODE
# -------------------------------
def resend_verification(payload: dict):
    email = payload.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")

    email = _normalize_email(email)

    conn = get_connection()
    try:
        cur = conn.cursor()

        cur.execute("SELECT id, is_verified FROM users WHERE email = %s", (email,))
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=400, detail="Email not found")

        user_id, is_verified = row
        if is_verified:
            return {"message": "Email already verified"}

        new_code = f"{random.randint(100000, 999999)}"
        expires_at = _now_utc_naive() + timedelta(minutes=10)

        cur.execute("""
            UPDATE users 
            SET verification_code = %s, verification_expires = %s, updated_at = %s
            WHERE id = %s
        """, (new_code, expires_at, _now_utc_naive(), user_id))
        conn.commit()

        send_verification_email(email, new_code)

        return {"message": "New verification code sent"}

    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# GOOGLE LOGIN
# -------------------------------
def google_login(data: dict):
    token = data.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="Missing token")

    try:
        payload = id_token.verify_oauth2_token(
            token, google_requests.Request(), CLIENT_ID
        )

        email = payload.get("email")
        name = payload.get("name", "") or ""
        if not email:
            raise HTTPException(status_code=400, detail="Google token missing email")

        email = _normalize_email(email)
        base_username = email.split("@")[0]

        conn = get_connection()
        try:
            cur = conn.cursor()

            # Existing user?
            cur.execute("SELECT id, provider FROM users WHERE email = %s", (email,))
            existing = cur.fetchone()

            if not existing:
                # Ensure username uniqueness for Google signup
                username = base_username
                if not USERNAME_REGEX.match(username):
                    # sanitize to allowed chars
                    username = re.sub(r"[^A-Za-z0-9._-]", "_", username)[:50]
                username = _ensure_unique_username(cur, username)

                cur.execute("""
                    INSERT INTO users 
                    (username, email, password_hash, full_name,
                     created_at, updated_at, provider, is_verified)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)
                    RETURNING id
                """,
                (
                    username,
                    email,
                    None,
                    name,
                    _now_utc_naive(),
                    _now_utc_naive(),
                    "google",
                ))
                new_id = cur.fetchone()[0]
                conn.commit()

                return {
                    "message": "User created with Google account",
                    "user_id": new_id,
                    "email": email,
                    "name": name,
                    "provider": "google",
                }

            else:
                user_id, provider = existing
                return {
                    "message": "Login successful with Google",
                    "user_id": user_id,
                    "email": email,
                    "name": name,
                    "provider": provider,
                }

        finally:
            conn.close()

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid Google token")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
ChatGPT said:

Thought for 9s
Got it — you want signup to ignore collisions from unverified accounts:

If an email exists but is not verified → reuse it: update that row (username/full name/password/code/expiry) and resend code.

For username checks, only treat as taken if a verified user owns it. Unverified usernames don’t block.

Here’s your updated module (full code) with those rules applied. I only touched signup_user and the username helper so everything stays clean.

from app.utils.validators import sanitize_non_empty, EMAIL_REGEX, USERNAME_REGEX
from app.utils.email_sender import send_verification_email
from app.schemas.user_schemas import UserCreate, UserLogin
from app.database import get_connection
from fastapi import HTTPException
from datetime import datetime, timedelta
import random
import re
import hashlib  # <-- plain hashing

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

# GOOGLE CLIENT ID
CLIENT_ID = "547065160142-m809lbb6qc4s7u6eohqbf77b32nld9q4.apps.googleusercontent.com"

# -------------------------------
# Helpers
# -------------------------------

def _now_utc_naive() -> datetime:
    """UTC now() without tzinfo to fit TIMESTAMP WITHOUT TIME ZONE columns."""
    return datetime.utcnow()

def _normalize_email(email: str) -> str:
    return email.strip().lower()

def _validate_password_strong(pw: str) -> None:
    """
    Strong policy:
      - >= 8 chars
      - at least one lowercase, one uppercase, one digit, one symbol
    """
    if len(pw) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters long")
    if not any(c.islower() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a lowercase letter")
    if not any(c.isupper() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include an uppercase letter")
    if not any(c.isdigit() for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a digit")
    symbols = "!@#$%^&*()_+-=[]{};':\",.<>/?\\|`~"
    if not any(c in symbols for c in pw):
        raise HTTPException(status_code=400, detail="Password must include a symbol")

def _ensure_unique_username(cur, base_username: str) -> str:
    """
    Make username unique **against verified users only**.
    Unverified usernames do NOT block reuse.
    """
    candidate = base_username
    suffix = 0
    while True:
        cur.execute(
            "SELECT 1 FROM users WHERE username = %s AND is_verified = TRUE",
            (candidate,),
        )
        if not cur.fetchone():
            return candidate
        suffix += 1
        candidate = f"{base_username}{suffix}"

# -------------------------------
# SIGNUP
# -------------------------------
def signup_user(user: UserCreate):
    """
    Rules:
      - If email exists & is_verified = TRUE => block ("Email already exists")
      - If email exists & is_verified = FALSE => REUSE that row: update fields, reset code/expiry, resend
      - Username uniqueness is checked only against verified users (unverified do not block)
    """
    conn = get_connection()
    try:
        cur = conn.cursor()

        # 1) Validate fields
        username = sanitize_non_empty(user.username, "Username", 50).strip()
        email = _normalize_email(sanitize_non_empty(user.email, "Email", 255))
        full_name = sanitize_non_empty(user.full_name, "Full name", 100).strip()

        if not USERNAME_REGEX.match(username):
            raise HTTPException(
                status_code=400,
                detail="Username can only contain letters, numbers, '.', '-' and '_'",
            )

        if not EMAIL_REGEX.match(email):
            raise HTTPException(status_code=400, detail="Invalid email address")

        if not user.password or not user.password.strip():
            raise HTTPException(status_code=400, detail="Password is required")

        password = user.password.strip()
        _validate_password_strong(password)

        # 2) Look up email (we branch depending on verified vs not)
        cur.execute("SELECT id, is_verified FROM users WHERE email = %s", (email,))
        existing = cur.fetchone()

        # Prepare common values
        password_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()
        code = f"{random.randint(100000, 999999)}"
        expires_at = _now_utc_naive() + timedelta(minutes=10)
        now = _now_utc_naive()

        # Username must be unique among verified users only
        # (We might be updating an existing unverified row — still we enforce this policy.)
        # If base username conflicts with a verified user, we suffix it.
        username = _ensure_unique_username(cur, username)

        if existing:
            user_id, is_verified = existing
            if is_verified:
                # Email already owned by a verified account => do not allow re-signup
                raise HTTPException(status_code=400, detail="Email already exists")

            # Email exists but NOT verified: reuse the same row and refresh everything
            cur.execute(
                """
                UPDATE users
                SET username = %s,
                    password_hash = %s,
                    full_name = %s,
                    provider = %s,
                    is_verified = FALSE,
                    verification_code = %s,
                    verification_expires = %s,
                    updated_at = %s
                WHERE id = %s
                """,
                (
                    username,
                    password_hash,
                    full_name,
                    "local",
                    code,
                    expires_at,
                    now,
                    user_id,
                ),
            )
            conn.commit()

            send_verification_email(email, code)
            return {
                "message": "Verification code resent (existing unverified account refreshed)",
                "email": email,
                "user_id": user_id,
            }

        # 3) Fresh insert (no email row)
        cur.execute(
            """
            INSERT INTO users 
            (username, email, password_hash, full_name, created_at, updated_at, 
             provider, is_verified, verification_code, verification_expires)
            VALUES (%s, %s, %s, %s, %s, %s, %s, FALSE, %s, %s)
            RETURNING id
            """,
            (
                username,
                email,
                password_hash,
                full_name,
                now,
                now,
                "local",
                code,
                expires_at,
            ),
        )
        user_id = cur.fetchone()[0]
        conn.commit()

        send_verification_email(email, code)
        return {"message": "Verification code sent", "email": email, "user_id": user_id}

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# LOGIN
# -------------------------------
def login_user(credentials: UserLogin):
    conn = get_connection()
    try:
        cur = conn.cursor()

        email = _normalize_email(credentials.email)

        cur.execute(
            "SELECT id, email, password_hash, provider, is_verified FROM users WHERE email = %s",
            (email,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        user_id, _email, stored_hash, provider, is_verified = row

        if provider == "google":
            raise HTTPException(
                status_code=400,
                detail="This account uses Google Sign-In. Please login with Google.",
            )

        if not is_verified:
            raise HTTPException(
                status_code=403,
                detail="Email not verified. Please verify your account.",
            )

        if not stored_hash:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        # SHA-256 verify
        input_hash = hashlib.sha256(credentials.password.encode("utf-8")).hexdigest()
        if stored_hash != input_hash:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        return {"message": "Login successful", "user_id": user_id, "provider": provider}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# VERIFY EMAIL CODE
# -------------------------------
def verify_email_code(payload: dict):
    email = payload.get("email")
    code = payload.get("code")

    if not email or not code:
        raise HTTPException(status_code=400, detail="Email and code required")

    email = _normalize_email(email)

    conn = get_connection()
    try:
        cur = conn.cursor()

        cur.execute("""
            SELECT id, verification_code, verification_expires, is_verified
            FROM users WHERE email = %s
        """, (email,))
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=400, detail="Email not found")

        user_id, stored_code, expires_at, is_verified = row
        now = _now_utc_naive()

        if is_verified and stored_code is None and expires_at is None:
            return {"message": "Email already verified"}

        if not stored_code or not expires_at or now > expires_at:
            raise HTTPException(status_code=400, detail="Verification code expired")

        if stored_code != code:
            raise HTTPException(status_code=400, detail="Invalid verification code")

        cur.execute("""
            UPDATE users 
            SET is_verified = TRUE, 
                verification_code = NULL, 
                verification_expires = NULL,
                updated_at = %s
            WHERE id = %s
        """, (_now_utc_naive(), user_id))
        conn.commit()

        return {"message": "Email verified successfully"}

    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# RESEND CODE
# -------------------------------
def resend_verification(payload: dict):
    email = payload.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")

    email = _normalize_email(email)

    conn = get_connection()
    try:
        cur = conn.cursor()

        cur.execute("SELECT id, is_verified FROM users WHERE email = %s", (email,))
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=400, detail="Email not found")

        user_id, is_verified = row
        if is_verified:
            return {"message": "Email already verified"}

        new_code = f"{random.randint(100000, 999999)}"
        expires_at = _now_utc_naive() + timedelta(minutes=10)

        cur.execute("""
            UPDATE users 
            SET verification_code = %s, verification_expires = %s, updated_at = %s
            WHERE id = %s
        """, (new_code, expires_at, _now_utc_naive(), user_id))
        conn.commit()

        send_verification_email(email, new_code)

        return {"message": "New verification code sent"}

    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

# -------------------------------
# GOOGLE LOGIN
# -------------------------------
def google_login(data: dict):
    token = data.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="Missing token")

    try:
        payload = id_token.verify_oauth2_token(
            token, google_requests.Request(), CLIENT_ID
        )

        email = payload.get("email")
        name = payload.get("name", "") or ""
        if not email:
            raise HTTPException(status_code=400, detail="Google token missing email")

        email = _normalize_email(email)
        base_username = email.split("@")[0]

        conn = get_connection()
        try:
            cur = conn.cursor()

            # Existing user?
            cur.execute("SELECT id, provider FROM users WHERE email = %s", (email,))
            existing = cur.fetchone()

            if not existing:
                # Ensure username uniqueness for Google signup (against verified only)
                username = base_username
                if not USERNAME_REGEX.match(username):
                    # sanitize to allowed chars
                    username = re.sub(r"[^A-Za-z0-9._-]", "_", username)[:50]
                username = _ensure_unique_username(cur, username)

                cur.execute("""
                    INSERT INTO users 
                    (username, email, password_hash, full_name,
                     created_at, updated_at, provider, is_verified)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)
                    RETURNING id
                """,
                (
                    username,
                    email,
                    None,
                    name,
                    _now_utc_naive(),
                    _now_utc_naive(),
                    "google",
                ))
                new_id = cur.fetchone()[0]
                conn.commit()

                return {
                    "message": "User created with Google account",
                    "user_id": new_id,
                    "email": email,
                    "name": name,
                    "provider": "google",
                }

            else:
                user_id, provider = existing
                return {
                    "message": "Login successful with Google",
                    "user_id": user_id,
                    "email": email,
                    "name": name,
                    "provider": provider,
                }

        finally:
            conn.close()

    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid Google token")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
Optional DB hardening (when you’re ready)
If you want the DB to enforce this rule too, use partial unique indexes (PostgreSQL):

-- make email unique only when verified
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email_verified
ON users (email)
WHERE is_verified = TRUE;

-- make username unique only when verified
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_username_verified
ON users (username)
WHERE is_verified = TRUE;
This way, verified accounts remain unique, while unverified rows don’t block re-use.

You said:
do we have to include somethin gextra ? to not let the user enter the next step after verification, if the the ydidnt verify their account
ChatGPT said:

Thought for 4 seconds
Short answer: yes—add server-side guards (mandatory) and a tiny client check (nice-to-have). You already block at login with 403 "Email not verified", which is great. Add the pieces below to fully seal it.

What to add (backend)
Gate every protected route
Create a dependency that refuses unverified users even if they somehow got a token/session:

# deps_auth.py
from fastapi import Depends, HTTPException
from .auth_utils import get_current_user  # your JWT/session user loader

def require_verified_user(current_user=Depends(get_current_user)):
    if not current_user.is_verified:
        raise HTTPException(status_code=403, detail="Email not verified. Please verify your account.")
    return current_user
Use it on any route that should be accessible only after verification:

# example protected route
@router.get("/me")
def me(user = Depends(require_verified_user)):
    return {"id": user.id, "email": user.email}
Even if a user crafts requests or bypasses UI, they can’t touch post-verification APIs.

Don’t issue tokens until verified (recommended)
If you’re using JWTs/sessions, either:

Refuse login until verified (you already do this), or

Issue a token with a claim is_verified=false and have require_verified_user enforce it.

If you go with the claim approach, include it in the token and check it in require_verified_user.

Consistent verification routes
Make sure the app and API agree on paths:

Verify code: POST /auth/verify-email

Resend: POST /auth/resend-verification

(Your EmailVerificationPage is using those—good.)

(Optional) Attempt & resend limits
Add verification_attempts and last_code_sent_at on the user row, throttle resends (e.g., ≥30s) and lock after N bad attempts for a cooldown. You’ve done UI cooldown; add a server check too.

What to add (frontend)
You already:

Redirect to EmailVerificationPage if login returns 403 with “verify”. ✅

Do these small extras:

After successful verification
On EmailVerificationPage, after “Email verified successfully”, pop to Login (you’re already Navigator.pop(context)), then show a snackbar “Verified — please log in”. That keeps the flow clean and prevents entering the app without a fresh login.

Optional status polling (only if you want auto-advance)
Add a light endpoint:

# GET /auth/status?email=...
@router.get("/auth/status")
def auth_status(email: str):
    # return {"is_verified": bool}
In EmailVerificationPage, you could offer a “I’ve verified” button that calls /auth/status and, if true, navigates back to Login.

Guard client navigation
Any screen that assumes an authenticated/verified user should fetch /me (or similar). If the backend returns 403 "Email not verified", kick them to EmailVerificationPage(email).

Minimal code you can drop in
FastAPI dependency (add once, reuse everywhere)
# app/deps_auth.py
from fastapi import Depends, HTTPException
from app.auth_utils import get_current_user  # implement to load user from JWT/session

def require_verified_user(current_user=Depends(get_current_user)):
    if not getattr(current_user, "is_verified", False):
        raise HTTPException(status_code=403, detail="Email not verified. Please verify your account.")
    return current_user
Use it on protected routes
# app/routes/profile_routes.py
from fastapi import APIRouter, Depends
from app.deps_auth import require_verified_user

router = APIRouter(prefix="/profile", tags=["profile"])

@router.get("/me")
def get_profile(user = Depends(require_verified_user)):
    return {"id": user.id, "email": user.email, "name": user.full_name}
Optional: status endpoint for polling
# app/routes/auth_routes.py
@router.get("/auth/status")
def auth_status(email: str):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT is_verified FROM users WHERE email = %s", (email.strip().lower(),))
        row = cur.fetchone()
        return {"is_verified": bool(row[0])} if row else {"is_verified": False}
    finally:
        conn.close()
Your current setup summary
Signup: reuses unverified accounts (✓ matches your requirement).

Login: returns 403 if not verified (✓).

UI: redirects to EmailVerificationPage on 403 (✓).

Next step: Add require_verified_user on all post-login routes and you’re done.

You said:
so its not for now , its when i create exra pages
ChatGPT said:
exactly — you’re good for now.

When you start adding extra (protected) pages/endpoints, do these two things:

Backend (per protected route)

# deps_auth.py
from fastapi import Depends, HTTPException
from app.auth_utils import get_current_user

def require_verified_user(current_user=Depends(get_current_user)):
    if not getattr(current_user, "is_verified", False):
        raise HTTPException(status_code=403, detail="Email not verified. Please verify your account.")
    return current_user
# some_routes.py
@router.get("/me")
def me(user = Depends(require_verified_user)):
    return {"id": user.id}
Frontend (when opening a protected screen)

Call a lightweight /me (or /auth/status) on init.

If you get 403 with “verify”, push EmailVerificationPage(email).

That’s it. Your current signup/login + verification flow is fine as-is.





Aucun fichier choisiAucun fichier choisi
ChatGPT can make mistakes. Check important info. See Cookie Preferences.
