import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class DividerWithLabel extends StatelessWidget {
  final String label;
  const DividerWithLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final lineColor = colors.divider;
    return Row(
      children: [
        Expanded(child: Divider(thickness: 1, color: lineColor)),
        Padding(
          padding: TaqaUiScale.symmetric(horizontal: 10),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(thickness: 1, color: lineColor)),
      ],
    );
  }
}
