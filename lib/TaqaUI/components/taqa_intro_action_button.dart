import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_styles.dart';

class TaqaIntroActionButton extends StatelessWidget {
  const TaqaIntroActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.width = TaqaUiStyles.actionButtonWidth,
    this.height = TaqaUiStyles.actionButtonHeight,
  });

  final String label;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: width, height: height),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: TaqaUiColors.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(label, style: TaqaUiStyles.actionButton)),
          ),
        ),
      ),
    );
  }
}
