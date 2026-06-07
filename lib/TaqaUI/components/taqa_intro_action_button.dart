import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_styles.dart';

class TaqaIntroActionButton extends StatelessWidget {
  const TaqaIntroActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? TaqaUiStyles.actionButtonWidth;
    final resolvedHeight = height ?? TaqaUiStyles.actionButtonHeight;
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(
        width: resolvedWidth,
        height: resolvedHeight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: TaqaUiStyles.actionButtonRadius,
          child: Ink(
            decoration: BoxDecoration(
              color: TaqaUiColors.lime,
              borderRadius: TaqaUiStyles.actionButtonRadius,
            ),
            child: Center(child: Text(label, style: TaqaUiStyles.actionButton)),
          ),
        ),
      ),
    );
  }
}
