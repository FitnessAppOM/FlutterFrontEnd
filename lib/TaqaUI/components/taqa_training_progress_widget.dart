import 'package:flutter/material.dart';

import 'taqa_progress_widget_card.dart';

class TaqaTrainingProgressWidget extends StatelessWidget {
  const TaqaTrainingProgressWidget({
    super.key,
    required this.loading,
    required this.completed,
    required this.total,
    required this.nextUpLabel,
    required this.nextUpAllDone,
    this.onTap,
    this.emptyStateLabel = 'Unavailable',
  });

  final bool loading;
  final int? completed;
  final int? total;
  final String? nextUpLabel;
  final bool nextUpAllDone;
  final VoidCallback? onTap;
  final String emptyStateLabel;

  @override
  Widget build(BuildContext context) {
    final safeCompleted = completed ?? 0;
    final safeTotal = total ?? 0;
    final progress = safeTotal > 0
        ? (safeCompleted / safeTotal).clamp(0.0, 1.0)
        : 0.0;
    final valueText = safeTotal > 0
        ? '$safeCompleted/$safeTotal'
        : '$safeCompleted';

    final hasNextUp = (nextUpLabel ?? '').trim().isNotEmpty;
    final goalText = loading
        ? 'Loading'
        : ((safeTotal > 0 && safeCompleted >= safeTotal) || nextUpAllDone)
        ? 'Done for week'
        : hasNextUp
        ? 'Next up: ${nextUpLabel!.trim()}'
        : emptyStateLabel;

    return TaqaProgressWidgetCard(
      title: 'Training Progress',
      valueText: valueText,
      goalText: goalText,
      progress: progress,
      loading: loading,
      lightSurface: false,
      onTap: onTap,
    );
  }
}
