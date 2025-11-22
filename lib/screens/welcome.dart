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
              // ======= TOP HEADER IMAGE (fills the empty space) =======
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Use your asset image
                      Image.asset(
                        'assets/images/BGWELC.jpg',
                        fit: BoxFit.cover,
                      ),
                      // Soft overlay for readability (optional)
                      Container(color: Colors.black.withOpacity(0.25)),
                    ],
                  ),
                ),
              ),

              Gaps.h24,

              // ======= Bottom content =======
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

                  // Main CTA
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
