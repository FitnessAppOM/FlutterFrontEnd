import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.title,
    required this.progress,
    this.targetLabel,
    this.accentColor = AppColors.accent,
  });

  final String title;
  final double progress; // 0..1
  final String? targetLabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final edgeColor = const Color(0xFFD4AF37).withValues(alpha: 0.18);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: edgeColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
              Text(
                "${(clamped * 100).round()}%",
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: clamped,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          if (targetLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              targetLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
