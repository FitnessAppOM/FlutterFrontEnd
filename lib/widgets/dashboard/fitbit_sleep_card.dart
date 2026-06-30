import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context).translate;
    final value = minutesAsleep != null
        ? _fmtMinutes(minutesAsleep!)
        : (loading ? "…" : "—");
    final subtitle = _buildSubtitle(t);
    final progress =
        (minutesAsleep != null && goalMinutes != null && goalMinutes! > 0)
        ? (minutesAsleep! / goalMinutes!).clamp(0.0, 1.0)
        : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: t("fitbit_sleep_title"),
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

  String _buildSubtitle(String Function(String) t) {
    final goalLabel = goalMinutes != null
        ? t("common_goal_value").replaceAll("{value}", _fmtMinutes(goalMinutes!))
        : null;
    final scoreLabel = sleepScore != null
        ? "${t("common_score_short")} ${sleepScore!}%"
        : null;
    final stageLabel = stageMinutes.isNotEmpty
        ? "${t("sleep_stages_label")} ${stageMinutes.length}"
        : null;
    final parts = [
      goalLabel,
      scoreLabel,
      stageLabel,
    ].whereType<String>().toList();
    return parts.isEmpty ? t("dash_no_sleep_data") : parts.join(" | ");
  }
}
