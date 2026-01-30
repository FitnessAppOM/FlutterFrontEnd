import 'package:flutter/material.dart';

class MonthlyDetailsButton extends StatelessWidget {
  const MonthlyDetailsButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.list_alt, color: Colors.white70, size: 18),
      label: const Text(
        "Details",
        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
