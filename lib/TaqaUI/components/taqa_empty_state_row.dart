import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Compact empty-state row for TaqaUI management lists.
class TaqaEmptyStateRow extends StatelessWidget {
  const TaqaEmptyStateRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: TaqaUiScale.h(42),
      padding: TaqaUiScale.insetsLTRB(14, 0, 14, 0),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(10),
          fontWeight: FontWeight.w400,
          height: 18 / 10,
          letterSpacing: 0,
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
      ),
    );
  }
}
