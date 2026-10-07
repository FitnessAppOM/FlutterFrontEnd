import 'package:flutter/material.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

class MonthlyDetailsButton extends StatelessWidget {
  const MonthlyDetailsButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.list_alt,
        color: context.taqaColors.textSecondary,
        size: 18,
      ),
      label: Text(
        "Details",
        style: TextStyle(
          color: context.taqaColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
