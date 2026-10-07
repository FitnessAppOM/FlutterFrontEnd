import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_pressable.dart';

/// Lime pill tab used for multi-section switchers (e.g. Diet's Rest/Training
/// day toggle, the expert dashboard's My Clients/Programs/Nutrition tabs) —
/// extracted so the same pattern doesn't get hand-copied per page.
class TaqaPillTab extends StatelessWidget {
  const TaqaPillTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.activeTextColor,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? activeColor;
  final Color? activeTextColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return TaqaPressable(
      onTap: onTap,
      child: Container(
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? (activeColor ?? colors.accent) : colors.surface,
          borderRadius: TaqaUiScale.radius(5),
          border: active ? null : Border.all(color: colors.border),
        ),
        child: Text(
          taqaUppercase(label),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? colors.textSecondary.withValues(alpha: 0.55)
                : (active
                      ? (activeTextColor ?? colors.onAccent)
                      : colors.textPrimary),
            height: 12 / 10,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
