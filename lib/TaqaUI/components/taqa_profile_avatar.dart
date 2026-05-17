import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_styles.dart';

class TaqaProfileAvatar extends StatelessWidget {
  const TaqaProfileAvatar({
    super.key,
    required this.child,
    this.size = TaqaUiStyles.avatarSize,
  });

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: TaqaUiColors.charcoal,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
