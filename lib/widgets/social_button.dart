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
