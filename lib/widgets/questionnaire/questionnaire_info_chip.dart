// lib/widgets/questionnaire_info_chip.dart
import 'package:flutter/material.dart';

class QuestionnaireInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const QuestionnaireInfoChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Chip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Text(label),
      backgroundColor: cs.primary.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
