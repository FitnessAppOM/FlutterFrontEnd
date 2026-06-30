import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class WhoopRecoveryCard extends StatelessWidget {
  const WhoopRecoveryCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.score,
    this.delta,
    this.maxScore = 100,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final int? score;
  final int? delta;
  final int maxScore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final value = linked
        ? (score != null ? "$score%" : (loading ? "…" : "—"))
        : t("whoop_not_connected");
    final safeMaxScore = maxScore <= 0 ? 100 : maxScore;
    final progress = linked && score != null
        ? (score! / safeMaxScore).clamp(0.0, 1.0)
        : 0.0;
    final subtitle = linked
        ? "${t("common_goal_value").replaceAll("{value}", "$safeMaxScore%")}${_deltaLabel(delta)}"
        : t("whoop_connect_title");

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.whoop,
      title: t("whoop_recovery_title"),
      valueText: value,
      goalText: subtitle,
      progress: progress,
      loading: loading && linked && score == null,
      onTap: onTap,
    );
  }

  String _deltaLabel(int? deltaValue) {
    if (deltaValue == null) return "";
    if (deltaValue == 0) return " | Δ 0%";
    final sign = deltaValue > 0 ? "+" : "-";
    return " | Δ $sign${deltaValue.abs()}%";
  }
}
