import 'package:flutter/material.dart';

import '../../TaqaUI/taqa_ui_colors.dart';

class CoachInfoPanel extends StatelessWidget {
  const CoachInfoPanel({
    super.key,
    required this.title,
    required this.bullets,
    required this.icon,
  });

  final String title;
  final List<String> bullets;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(icon, color: context.taqaColors.accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: context.taqaColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.taqaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.taqaColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bullets
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '- $line',
                      style: TextStyle(color: context.taqaColors.textSecondary),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
