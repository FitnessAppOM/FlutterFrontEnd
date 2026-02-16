import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class EditModeBubble extends StatelessWidget {
  final bool visible;
  final VoidCallback? onTap;

  const EditModeBubble({
    super.key,
    required this.visible,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 180),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
