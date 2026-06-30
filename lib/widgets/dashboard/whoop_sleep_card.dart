import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

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
  });

  final bool loading;
  final bool linked;
  final bool linkedKnown;
  final double? hours;
  final int? score;
  final double normalSleepGoalHours;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final value = !linkedKnown
        ? "…"
        : linked
        ? (hours != null ? _formatHours(hours!) : (loading ? "…" : "—"))
        : t("whoop_not_connected");
    final goalHours = normalSleepGoalHours > 0 ? normalSleepGoalHours : 8.0;
    final progress = linked && hours != null && goalHours > 0
        ? (hours! / goalHours).clamp(0.0, 1.0)
        : 0.0;
    final subtitle = !linkedKnown
        ? t("common_loading")
        : linked
        ? t("common_goal_value").replaceAll("{value}", _formatHours(goalHours))
        : t("whoop_connect_title");
    final efficiency = score;
    final loadingState =
        !linkedKnown ||
        (loading && linked && hours == null && efficiency == null);

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.whoop,
      title: t("whoop_sleep_title"),
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loadingState,
      onTap: onTap,
    );
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}h ${m}m";
  }
}
