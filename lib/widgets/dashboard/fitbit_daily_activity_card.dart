import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

class FitbitDailyActivityCard extends StatelessWidget {
  final bool loading;
  final int? steps;
  final double? distanceKm;
  final int? calories;
  final int? activeMinutes;
  final int? goalSteps;
  final int? goalCalories;
  final int? goalActiveMinutes;
  final VoidCallback? onTap;

  const FitbitDailyActivityCard({
    super.key,
    required this.loading,
    required this.steps,
    required this.distanceKm,
    required this.calories,
    required this.activeMinutes,
    this.goalSteps,
    this.goalCalories,
    this.goalActiveMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Main metric: prefer active minutes, fall back to steps, then calories.
    final String? mainLabel;
    final num? mainValue;
    final num? mainGoal;
    if (activeMinutes != null) {
      mainLabel = "min";
      mainValue = activeMinutes;
      mainGoal = goalActiveMinutes;
    } else if (steps != null) {
      mainLabel = "steps";
      mainValue = steps;
      mainGoal = goalSteps;
    } else if (calories != null) {
      mainLabel = "cal";
      mainValue = calories;
      mainGoal = goalCalories;
    } else {
      mainLabel = null;
      mainValue = null;
      mainGoal = null;
    }

    final value = mainValue == null
        ? (loading ? "…" : "—")
        : mainLabel == "min"
            ? "${mainValue}m"
            : "$mainValue $mainLabel";

    // Single subtitle field below the arc, in priority order, skipping
    // whichever metric is already shown as the main value.
    String? subtitle;
    if (mainLabel != "distance" && distanceKm != null) {
      subtitle = "${distanceKm!.toStringAsFixed(1)} km";
    } else if (mainLabel != "steps" && steps != null) {
      subtitle = "$steps steps";
    } else if (mainLabel != "cal" && calories != null) {
      subtitle = "$calories cal";
    }
    subtitle ??= loading ? "Loading" : "—";

    final showArc = mainValue != null && mainGoal != null && mainGoal > 0;
    final progress =
        showArc ? (mainValue / mainGoal).clamp(0.0, 1.0).toDouble() : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Fitbit activity",
      valueText: value,
      goalText: subtitle,
      progress: progress,
      showArc: showArc,
      loading: loading && mainValue == null,
      onTap: onTap,
    );
  }
}
