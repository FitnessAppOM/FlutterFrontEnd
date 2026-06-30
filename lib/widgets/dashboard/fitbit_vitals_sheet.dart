import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/fitbit/fitbit_vitals_service.dart';
import '../../localization/app_localizations.dart';

class FitbitVitalsSheet extends StatelessWidget {
  final FitbitVitalsSummary? summary;

  const FitbitVitalsSheet({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1F27), Color(0xFF13151C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            children: [
              Text(t("fitbit_vitals_title"),
                  style: AppTextStyles.subtitle.copyWith(color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: t("fitbit_vitals_spo2_avg"),
            value: summary?.spo2Percent == null
                ? "—"
                : "${summary!.spo2Percent!.toStringAsFixed(0)}%",
          ),
          _MetricRow(
            label: t("fitbit_vitals_spo2_minmax"),
            value: (summary?.spo2Min == null && summary?.spo2Max == null)
                ? "—"
                : "${summary?.spo2Min?.toStringAsFixed(0) ?? "—"} / ${summary?.spo2Max?.toStringAsFixed(0) ?? "—"}",
          ),
          _MetricRow(
            label: t("fitbit_vitals_skin_temp_delta"),
            value: summary?.skinTempC == null
                ? "—"
                : _fmtTemp(summary!.skinTempC!),
          ),
          _MetricRow(
            label: t("fitbit_vitals_breathing_rate"),
            value: summary?.breathingRate == null
                ? "—"
                : "${summary!.breathingRate!.toStringAsFixed(1)}",
          ),
          _MetricRow(
            label: t("fitbit_vitals_ecg"),
            value: summary?.ecgSummary == null
                ? "—"
                : _fmtEcg(summary!.ecgSummary!, summary?.ecgAvgHr),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _fmtTemp(double v) {
    final sign = v >= 0 ? "+" : "";
    return "$sign${v.toStringAsFixed(1)}°C";
  }

  String _fmtEcg(String summary, int? avgHr) {
    if (avgHr == null) return summary;
    return "$summary • $avgHr bpm";
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
