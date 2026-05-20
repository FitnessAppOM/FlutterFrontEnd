import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

class FitbitVitalsCard extends StatelessWidget {
  final bool loading;
  final double? spo2Percent;
  final double? skinTempC;
  final double? breathingRate;
  final String? ecgSummary;
  final int? ecgAvgHr;
  final VoidCallback? onTap;

  const FitbitVitalsCard({
    super.key,
    required this.loading,
    required this.spo2Percent,
    required this.skinTempC,
    required this.breathingRate,
    required this.ecgSummary,
    required this.ecgAvgHr,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = _buildValue();
    final subtitle = _buildSubtitle();

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: "Fitbit health",
      valueText: value,
      goalText: subtitle ?? "No vitals data",
      progress: 0.0,
      showArc: false,
      loading:
          loading &&
          spo2Percent == null &&
          skinTempC == null &&
          breathingRate == null &&
          ecgSummary == null,
      onTap: onTap,
    );
  }

  String _buildValue() {
    if (loading) return "…";
    if (spo2Percent != null) return "SpO₂ ${spo2Percent!.toStringAsFixed(0)}%";
    if (breathingRate != null) return "BR ${breathingRate!.toStringAsFixed(1)}";
    if (skinTempC != null) return "Temp ${_fmtTemp(skinTempC!)}";
    if (ecgSummary != null) return "ECG ${ecgSummary!}";
    return "—";
  }

  String? _buildSubtitle() {
    if (loading) return null;
    final parts = <String>[];
    if (skinTempC != null) parts.add("Temp ${_fmtTemp(skinTempC!)}");
    if (breathingRate != null) {
      parts.add("BR ${breathingRate!.toStringAsFixed(1)}");
    }
    if (ecgSummary != null) {
      final hr = ecgAvgHr != null ? " $ecgAvgHr bpm" : "";
      parts.add("ECG $ecgSummary$hr");
    }
    return parts.isEmpty ? null : parts.join(" • ");
  }

  String _fmtTemp(double v) {
    final sign = v >= 0 ? "+" : "";
    return "$sign${v.toStringAsFixed(1)}°C";
  }
}
