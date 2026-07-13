import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Lime pill tab used for multi-section switchers (e.g. Diet's Rest/Training
/// day toggle, the expert dashboard's My Clients/Programs/Nutrition tabs) —
/// extracted so the same pattern doesn't get hand-copied per page.
class TaqaPillTab extends StatelessWidget {
  const TaqaPillTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? TaqaUiColors.lime : TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(5),
          border: active
              ? null
              : Border.all(color: TaqaUiColors.charcoal.withValues(alpha: 0.12)),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? TaqaUiColors.charcoal.withValues(alpha: 0.35)
                : TaqaUiColors.charcoal,
            height: 12 / 10,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
