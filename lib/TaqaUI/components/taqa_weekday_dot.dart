import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_styles.dart';

enum TaqaWeekdayStatus { past, current, future }

class TaqaWeekdayDot extends StatelessWidget {
  const TaqaWeekdayDot({
    super.key,
    required this.label,
    required this.status,
    this.size = 64,
  });

  final String label;
  final TaqaWeekdayStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = switch (status) {
      TaqaWeekdayStatus.past => TaqaUiColors.weekdayPast,
      TaqaWeekdayStatus.current => TaqaUiColors.lime,
      TaqaWeekdayStatus.future => TaqaUiColors.weekdayFuture,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: TaqaUiStyles.circleRadius,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TaqaUiStyles.weekdayLabel),
      ],
    );
  }
}
