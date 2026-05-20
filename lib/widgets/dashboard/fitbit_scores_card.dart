import 'package:flutter/material.dart';

import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

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
    final value = _buildValue();
    final subtitle = _buildSubtitle();
    final progress = (readinessScore ?? stressManagementScore) != null
        ? (((readinessScore ?? stressManagementScore)! / 100.0).clamp(0.0, 1.0))
        : 0.0;

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Fitbit scores",
      valueText: value,
      goalText: subtitle ?? "No score data",
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

  String? _buildSubtitle() {
    if (loading) return null;
    final parts = <String>[];
    if (readinessScore != null) parts.add("Ready ${_pct(readinessScore!)}");
    if (stressManagementScore != null) {
      parts.add("Stress ${_pct(stressManagementScore!)}");
    }
    return parts.isEmpty ? null : parts.join(" • ");
  }

  String _pct(int v) => "$v%";
}
