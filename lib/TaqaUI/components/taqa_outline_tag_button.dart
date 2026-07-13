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
    this.icon,
    this.borderColor,
    this.textStyle,
  });

  final String label;
  final double width;
  final double? height;
  final VoidCallback? onTap;

  /// Optional small leading icon (e.g. a bell) shown before the label.
  final Widget? icon;

  /// Overrides the default charcoal border (e.g. for an accent state).
  final Color? borderColor;

  /// Overrides the default [TaqaUiStyles.streakTag] text style.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final content = icon == null
        ? Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? TaqaUiStyles.streakTag,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon!,
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle ?? TaqaUiStyles.streakTag,
              ),
            ],
          );
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
            border: Border.all(
              color: borderColor ?? TaqaUiColors.charcoal,
              width: 0.5,
            ),
            borderRadius: TaqaUiStyles.streakTagRadius,
          ),
          child: content,
        ),
      ),
    );
  }
}
