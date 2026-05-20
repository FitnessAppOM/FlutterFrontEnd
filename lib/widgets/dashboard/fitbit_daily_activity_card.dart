import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

class FitbitDailyActivityCard extends StatelessWidget {
  final bool loading;
  final int? steps;
  final double? distanceKm;
  final int? calories;
  final int? activeMinutes;
  final VoidCallback? onTap;

  const FitbitDailyActivityCard({
    super.key,
    required this.loading,
    required this.steps,
    required this.distanceKm,
    required this.calories,
    required this.activeMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = activeMinutes != null
        ? "${activeMinutes}m"
        : (loading ? "…" : "—");
    final dist = distanceKm == null
        ? "—"
        : "${distanceKm!.toStringAsFixed(1)} km";
    final subtitle = loading
        ? "Loading"
        : (steps != null ? "$dist | $steps steps" : dist);
    final progress = activeMinutes != null
        ? (activeMinutes! / 60.0).clamp(0.0, 1.0)
        : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Fitbit activity",
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loading && activeMinutes == null,
      onTap: onTap,
    );
  }
}
