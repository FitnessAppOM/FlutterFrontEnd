import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

class FitbitHeartCard extends StatelessWidget {
  final bool loading;
  final int? restingHr;
  final double? hrvRmssd;
  final String? vo2Max;
  final VoidCallback? onTap;

  const FitbitHeartCard({
    super.key,
    required this.loading,
    required this.restingHr,
    required this.hrvRmssd,
    required this.vo2Max,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = restingHr != null
        ? "$restingHr bpm"
        : (loading ? "…" : "—");
    final hrv = hrvRmssd != null ? "HRV ${hrvRmssd!.toStringAsFixed(0)}" : null;
    final vo2 = vo2Max != null && vo2Max!.isNotEmpty ? "VO₂ ${vo2Max!}" : null;
    final subtitle = [hrv, vo2].whereType<String>().join(" • ");

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Heart & cardio",
      valueText: value,
      goalText: subtitle.isEmpty ? "No heart details" : subtitle,
      progress: 0.0,
      showArc: false,
      loading:
          loading && restingHr == null && hrvRmssd == null && vo2Max == null,
      onTap: onTap,
    );
  }
}
