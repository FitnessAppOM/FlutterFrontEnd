import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Two-state pill toggle (e.g. Weekly/Daily) — filled charcoal when
/// selected, outlined when not. Shared so any settings-style schedule
/// picker stays visually consistent instead of a one-off ChoiceChip.
class TaqaSegmentedToggleButton extends StatelessWidget {
  const TaqaSegmentedToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TaqaUiScale.radius(5),
      onTap: onTap,
      child: Container(
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? TaqaUiColors.charcoal : null,
          borderRadius: TaqaUiScale.radius(5),
          border: selected ? null : Border.all(color: TaqaUiColors.charcoal),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w600,
            height: 12 / 10,
            letterSpacing: 0,
            color: selected ? TaqaUiColors.white : TaqaUiColors.charcoal,
          ),
        ),
      ),
    );
  }
}
