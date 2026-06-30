import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context).translate;

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
            ? "$mainValue${t("fitbit_unit_min")}"
            : "$mainValue ${t(mainLabel == "steps" ? "fitbit_unit_steps" : "fitbit_unit_cal")}";

    // Single subtitle field below the arc, in priority order, skipping
    // whichever metric is already shown as the main value.
    String? subtitle;
    if (mainLabel != "distance" && distanceKm != null) {
      subtitle = "${distanceKm!.toStringAsFixed(1)} km";
    } else if (mainLabel != "steps" && steps != null) {
      subtitle = "$steps ${t("fitbit_unit_steps")}";
    } else if (mainLabel != "cal" && calories != null) {
      subtitle = "$calories ${t("fitbit_unit_cal")}";
    }
    subtitle ??= loading ? t("common_loading") : "—";

    final showArc = mainValue != null && mainGoal != null && mainGoal > 0;
    final progress =
        showArc ? (mainValue / mainGoal).clamp(0.0, 1.0).toDouble() : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: t("fitbit_activity_card_title"),
      valueText: value,
      goalText: subtitle,
      progress: progress,
      showArc: showArc,
      loading: loading && mainValue == null,
      onTap: onTap,
    );
  }
}
