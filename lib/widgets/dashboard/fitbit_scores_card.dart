import 'package:flutter/material.dart';

import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class FitbitScoresCard extends StatelessWidget {
  final bool loading;
  final int? readinessScore;
  final int? stressManagementScore;
  final VoidCallback? onTap;

  const FitbitScoresCard({
    super.key,
    required this.loading,
    required this.readinessScore,
    required this.stressManagementScore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final value = _buildValue();
    final subtitle = _buildSubtitle(t);
    final progress = (readinessScore ?? stressManagementScore) != null
        ? (((readinessScore ?? stressManagementScore)! / 100.0).clamp(0.0, 1.0))
        : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: t("fitbit_scores_title"),
      valueText: value,
      goalText: subtitle ?? t("fitbit_scores_no_data"),
      progress: progress,
      loading:
          loading && readinessScore == null && stressManagementScore == null,
      onTap: onTap,
    );
  }

  String _buildValue() {
    if (loading) return "…";
    if (readinessScore != null) return _pct(readinessScore!);
    if (stressManagementScore != null) return _pct(stressManagementScore!);
    return "—";
  }

  String? _buildSubtitle(String Function(String) t) {
    if (loading) return null;
    final parts = <String>[];
    if (readinessScore != null) {
      parts.add("${t("fitbit_scores_ready_short")} ${_pct(readinessScore!)}");
    }
    if (stressManagementScore != null) {
      parts.add(
        "${t("fitbit_scores_stress_short")} ${_pct(stressManagementScore!)}",
      );
    }
    return parts.isEmpty ? null : parts.join(" • ");
  }

  String _pct(int v) => "$v%";
}
