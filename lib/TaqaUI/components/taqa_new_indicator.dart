import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Inline TaqaUI marker for content the current user has not seen yet.
class TaqaNewIndicator extends StatelessWidget {
  const TaqaNewIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: TaqaUiScale.w(6),
          height: TaqaUiScale.h(6),
          decoration: const BoxDecoration(
            color: TaqaUiColors.recordRed,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: TaqaUiScale.w(4)),
        Text(
          'NEW',
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
            fontSize: TaqaUiScale.sp(8),
            fontWeight: FontWeight.w400,
            height: 10 / 8,
            letterSpacing: 0,
            color: TaqaUiColors.recordRed,
          ),
        ),
      ],
    );
  }
}
