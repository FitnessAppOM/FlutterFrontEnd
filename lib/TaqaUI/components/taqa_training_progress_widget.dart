import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
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
    final t = AppLocalizations.of(context).translate;
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
        ? t('dashboard_training_loading')
        : ((safeTotal > 0 && safeCompleted >= safeTotal) || nextUpAllDone)
        ? t('dashboard_training_done_week')
        : hasNextUp
        ? '${t('dashboard_training_next')}: ${nextUpLabel!.trim()}'
        : emptyStateLabel;

    return TaqaProgressWidgetCard(
      title: t('dashboard_training_progress'),
      valueText: valueText,
      goalText: goalText,
      progress: progress,
      loading: loading,
      lightSurface: false,
      onTap: onTap,
    );
  }
}
