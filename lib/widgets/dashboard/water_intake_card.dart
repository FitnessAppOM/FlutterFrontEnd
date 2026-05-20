import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';

class WaterIntakeCard extends StatelessWidget {
  final bool loading;
  final double intakeLiters;
  final double goalLiters;
  final int? deltaPercent;
  final VoidCallback? onTap;

  const WaterIntakeCard({
    super.key,
    required this.loading,
    required this.intakeLiters,
    required this.goalLiters,
    this.deltaPercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = loading ? "…" : "${intakeLiters.toStringAsFixed(1)} L";
    final subtitle = loading ? "Loading" : "Goal ${goalLiters.toStringAsFixed(1)} L";
    final progress = goalLiters > 0
        ? (intakeLiters / goalLiters).clamp(0.0, 1.0)
        : 0.0;

    return TaqaProgressWidgetCard(
      title: "Water intake",
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loading,
      onTap: onTap,
    );
  }
}
