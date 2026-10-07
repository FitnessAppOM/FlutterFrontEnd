import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import 'taqa_pressable.dart';

class TaqaEditModeBubble extends StatelessWidget {
  const TaqaEditModeBubble({super.key, required this.visible, this.onTap});

  final bool visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 180),
          child: TaqaPressable(
            onTap: onTap,
            pressedScale: 0.94,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.scrim.withValues(alpha: 0.26),
                    blurRadius: 30,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              child: Icon(Icons.add, color: colors.textPrimary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
