import 'package:flutter/material.dart';

import '../../TaqaUI/taqa_ui_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        Container(height: 3, width: 40, color: colors.accent),
      ],
    );
  }
}
