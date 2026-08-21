import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared circular back button used across Taqa UI screens.
///
/// Sizes scale with [TaqaUiScale] so the tap target and icon stay
/// consistent (and legible) across device sizes, instead of falling back
/// to the default Material [AppBar] leading icon which renders tiny on
/// some screens.
class TaqaBackButton extends StatelessWidget {
  const TaqaBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 18,
    this.splashRadius = 24,
    this.touchSize = 52,
  });

  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double splashRadius;
  final double touchSize;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? TaqaUiColors.white
            : TaqaUiColors.charcoal);
    final targetSize = TaqaUiScale.w(touchSize).clamp(48.0, 60.0);
    return SizedBox.square(
      dimension: targetSize,
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        splashRadius: TaqaUiScale.w(splashRadius),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: targetSize,
          height: targetSize,
        ),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icon(
          // Material's back icon mirrors itself for RTL. Picking a different
          // icon manually would mirror it twice and make it point the wrong way.
          Icons.arrow_back_ios_new,
          color: resolvedColor,
          size: TaqaUiScale.w(iconSize),
        ),
      ),
    );
  }
}
