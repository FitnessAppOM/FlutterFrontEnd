import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SleepProgressBar extends StatelessWidget {
  const SleepProgressBar({
    super.key,
    required this.value,
  });

  final double value;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 10,
          width: width,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: width * clamped,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00BFA6),
                    Color(0xFF35B6FF),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
