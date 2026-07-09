import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared pill on/off switch used across Taqa UI (group settings, dialogs,
/// ...) so toggles stay visually consistent instead of falling back to the
/// default Material [Switch].
class TaqaSwitch extends StatelessWidget {
  const TaqaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width,
    this.height,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final trackWidth = width ?? TaqaUiScale.w(38);
    final trackHeight = height ?? TaqaUiScale.h(20);
    final thumbInset = TaqaUiScale.w(2);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: trackWidth,
        height: trackHeight,
        padding: EdgeInsets.all(thumbInset),
        decoration: BoxDecoration(
          color: value
              ? TaqaUiColors.lime
              : TaqaUiColors.charcoal.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(trackHeight),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
