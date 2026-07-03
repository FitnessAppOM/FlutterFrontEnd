import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class TaqaOutlineTagButton extends StatelessWidget {
  const TaqaOutlineTagButton({
    super.key,
    required this.label,
    required this.width,
    this.height,
    this.onTap,
  });

  final String label;
  final double width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.streakTagRadius,
        child: Container(
          width: width,
          height: height ?? TaqaUiStyles.streakTagHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: TaqaUiColors.charcoal, width: 0.5),
            borderRadius: TaqaUiStyles.streakTagRadius,
          ),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaqaUiStyles.streakTag,
          ),
        ),
      ),
    );
  }
}
