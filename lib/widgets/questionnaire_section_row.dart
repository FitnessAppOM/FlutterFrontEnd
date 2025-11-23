// lib/widgets/questionnaire_section_row.dart
import 'package:flutter/material.dart';

class QuestionnaireSectionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const QuestionnaireSectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
