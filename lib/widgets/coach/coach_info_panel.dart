import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
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
                      style: const TextStyle(color: Colors.white70),
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
