import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';

class WhoopSleepCard extends StatelessWidget {
  const WhoopSleepCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.linkedKnown,
    required this.hours,
    required this.score,
    required this.normalSleepGoalHours,
    this.onTap,
    this.showEfficiency = true,
  });

  final bool loading;
  final bool linked;
  final bool linkedKnown;
  final double? hours;
  final int? score;
  final double normalSleepGoalHours;
  final VoidCallback? onTap;
  final bool showEfficiency;

  @override
  Widget build(BuildContext context) {
    final value = !linkedKnown
        ? "…"
        : linked
            ? (hours != null ? _formatHours(hours!) : (loading ? "…" : "—"))
            : "Not connected";
    final goalHours = normalSleepGoalHours > 0 ? normalSleepGoalHours : 8.0;
    final progress = linked && hours != null && goalHours > 0
        ? (hours! / goalHours).clamp(0.0, 1.0)
        : 0.0;
    final subtitle = !linkedKnown
        ? "Loading"
        : linked
        ? _goalText(goalHours, score)
        : "Connect Whoop";
    final efficiency = score;
    final loadingState =
        !linkedKnown || (loading && linked && hours == null && efficiency == null);

    return TaqaProgressWidgetCard(
      title: "Whoop Sleep",
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loadingState,
      onTap: onTap,
    );
  }

  String _goalText(double goalHours, int? efficiency) {
    final base = "Goal: ${_formatHours(goalHours)}";
    if (showEfficiency && efficiency != null) {
      return "$base | Efficiency: ${efficiency.toStringAsFixed(0)}%";
    }
    return base;
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}h ${m}m";
  }
}
