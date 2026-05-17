import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'taqa_progress_widget_card.dart';

class TaqaDietProgressWidget extends StatelessWidget {
  const TaqaDietProgressWidget({
    super.key,
    required this.loading,
    required this.consumedCalories,
    required this.targetCalories,
    this.onTap,
  });

  final bool loading;
  final int? consumedCalories;
  final int? targetCalories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final consumed = consumedCalories ?? 0;
    final target = targetCalories ?? 0;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final targetText = target > 0 ? '${_fmt(target)} kcal' : 'No target';

    return TaqaProgressWidgetCard(
      title: 'Diet Progress',
      valueText: '$consumed',
      goalText: loading ? 'Loading' : targetText,
      progress: progress,
      loading: loading,
      onTap: onTap,
    );
  }

  String _fmt(int value) {
    return NumberFormat.decimalPattern().format(value);
  }
}
