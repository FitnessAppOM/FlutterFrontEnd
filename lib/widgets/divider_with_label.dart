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
