import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_styles.dart';

class TaqaProfileAvatar extends StatelessWidget {
  const TaqaProfileAvatar({
    super.key,
    required this.child,
    this.size,
  });

  final Widget child;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? TaqaUiStyles.avatarSize;
    return Container(
      width: resolvedSize,
      height: resolvedSize,
      decoration: BoxDecoration(
        color: TaqaUiColors.charcoal,
        borderRadius: TaqaUiStyles.avatarRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
