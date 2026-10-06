import 'package:flutter/material.dart';

import '../../TaqaUI/taqa_ui_colors.dart';

class CardContainer extends StatelessWidget {
  final Widget child;

  const CardContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        // Match the subtle gold edge treatment used across other widgets.
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}
