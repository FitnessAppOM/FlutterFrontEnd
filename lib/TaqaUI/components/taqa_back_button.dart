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
    this.color = TaqaUiColors.charcoal,
    this.iconSize = 18,
    this.splashRadius = 20,
  });

  final VoidCallback? onPressed;
  final Color color;
  final double iconSize;
  final double splashRadius;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      splashRadius: TaqaUiScale.w(splashRadius),
      icon: Icon(
        isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
        color: color,
        size: TaqaUiScale.w(iconSize),
      ),
    );
  }
}
