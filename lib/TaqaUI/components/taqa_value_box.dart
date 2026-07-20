import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Compact white value card used for expert-client metric summaries.
///
/// The card starts at the design size (109 x 85), then grows horizontally when
/// either the label or value needs more room. This keeps long metric text on
/// one line without changing the prescribed vertical rhythm.
class TaqaValueBox extends StatelessWidget {
  const TaqaValueBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(minWidth: TaqaUiScale.w(109)),
        height: TaqaUiScale.h(85),
        padding: TaqaUiScale.insetsLTRB(13, 12, 13, 15),
        decoration: BoxDecoration(
          color: TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: TaqaUiColors.unnamedColor1c1d17,
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: TaqaUiScale.sp(8),
                fontWeight: FontWeight.w400,
                height: 10 / 8,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              value.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: TaqaUiColors.unnamedColor1c1d17,
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(25),
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
