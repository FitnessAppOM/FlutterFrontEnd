import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

class FitbitSleepCard extends StatelessWidget {
  final bool loading;
  final int? minutesAsleep;
  final int? minutesInBed;
  final int? goalMinutes;
  final int? sleepScore;
  final Map<String, int> stageMinutes;
  final VoidCallback? onTap;

  const FitbitSleepCard({
    super.key,
    required this.loading,
    required this.minutesAsleep,
    required this.minutesInBed,
    required this.goalMinutes,
    this.sleepScore,
    this.stageMinutes = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = minutesAsleep != null
        ? _fmtMinutes(minutesAsleep!)
        : (loading ? "…" : "—");
    final subtitle = _buildSubtitle();
    final progress =
        (minutesAsleep != null && goalMinutes != null && goalMinutes! > 0)
        ? (minutesAsleep! / goalMinutes!).clamp(0.0, 1.0)
        : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Fitbit sleep",
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loading && minutesAsleep == null && sleepScore == null,
      onTap: onTap,
    );
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "${h}h ${m}m";
  }

  String _buildSubtitle() {
    final goalLabel = goalMinutes != null
        ? "Goal ${_fmtMinutes(goalMinutes!)}"
        : null;
    final scoreLabel = sleepScore != null ? "Score ${sleepScore!}%" : null;
    final stageLabel = stageMinutes.isNotEmpty
        ? "Stages ${stageMinutes.length}"
        : null;
    final parts = [
      goalLabel,
      scoreLabel,
      stageLabel,
    ].whereType<String>().toList();
    return parts.isEmpty ? "No sleep data" : parts.join(" | ");
  }
}
