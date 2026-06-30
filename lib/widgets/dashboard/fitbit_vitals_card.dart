import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context).translate;
    final value = _buildValue(t);
    final subtitle = _buildSubtitle(t);

    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: t("fitbit_vitals_title"),
      valueText: value,
      goalText: subtitle ?? t("fitbit_vitals_no_data"),
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

  String _buildValue(String Function(String) t) {
    if (loading) return "…";
    if (spo2Percent != null) return "${t("fitbit_vitals_spo2_label")} ${spo2Percent!.toStringAsFixed(0)}%";
    if (breathingRate != null) return "${t("fitbit_vitals_br_label")} ${breathingRate!.toStringAsFixed(1)}";
    if (skinTempC != null) return "${t("fitbit_vitals_temp_label")} ${_fmtTemp(skinTempC!)}";
    if (ecgSummary != null) return "${t("fitbit_vitals_ecg_label")} $ecgSummary";
    return "—";
  }

  String? _buildSubtitle(String Function(String) t) {
    if (loading) return null;
    final parts = <String>[];
    if (skinTempC != null) parts.add("${t("fitbit_vitals_temp_label")} ${_fmtTemp(skinTempC!)}");
    if (breathingRate != null) {
      parts.add("${t("fitbit_vitals_br_label")} ${breathingRate!.toStringAsFixed(1)}");
    }
    if (ecgSummary != null) {
      final hr = ecgAvgHr != null ? " $ecgAvgHr bpm" : "";
      parts.add("${t("fitbit_vitals_ecg_label")} $ecgSummary$hr");
    }
    return parts.isEmpty ? null : parts.join(" • ");
  }

  String _fmtTemp(double v) {
    final sign = v >= 0 ? "+" : "";
    return "$sign${v.toStringAsFixed(1)}°C";
  }
}
