import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared page/section loading spinner — charcoal, 2px stroke, 20x20 by
/// default. Use this instead of a bare [CircularProgressIndicator] so every
/// loading state across the app looks the same (same color/size), matching
/// the spinner [TaqaRefreshIndicator] already uses for pull-to-refresh.
class TaqaLoadingIndicator extends StatelessWidget {
  const TaqaLoadingIndicator({
    super.key,
    this.size = 20,
    this.color = TaqaUiColors.charcoal,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TaqaUiScale.w(size),
      height: TaqaUiScale.h(size),
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
