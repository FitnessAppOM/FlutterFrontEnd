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
