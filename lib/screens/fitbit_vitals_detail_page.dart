import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_vitals_service.dart';

class FitbitVitalsDetailPage extends StatelessWidget {
  const FitbitVitalsDetailPage({super.key, required this.summary});

  final FitbitVitalsSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final hasData =
        summary != null &&
        (summary!.spo2Percent != null ||
            summary!.skinTempC != null ||
            summary!.breathingRate != null ||
            summary!.ecgSummary != null);

    return Scaffold(
      appBar: TaqaPageAppBar(
        title: t("fitbit_vitals_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      ),
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: !hasData
                ? TaqaEmptyCard(
                    title: t("fitbit_vitals_title"),
                    subtitle: t("common_no_records_in_range"),
                    icon: Icons.favorite_border,
                  )
                : Column(
                    children: [
                      TaqaPillarCard(
                        metricKey: 'spo2_avg',
                        label: t("fitbit_vitals_spo2_avg"),
                        score: summary?.spo2Percent,
                        maxScore: 100,
                        icon: Icons.air_rounded,
                        color: const Color(0xFF35B6FF),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: summary?.spo2Percent == null
                            ? null
                            : "${summary!.spo2Percent!.toStringAsFixed(0)}%",
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaPillarCard(
                        metricKey: 'spo2_minmax',
                        label: t("fitbit_vitals_spo2_minmax"),
                        score: _avgOf(summary?.spo2Min, summary?.spo2Max),
                        maxScore: 100,
                        icon: Icons.water_drop_rounded,
                        color: const Color(0xFF00BFA6),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay:
                            (summary?.spo2Min == null &&
                                summary?.spo2Max == null)
                            ? null
                            : "${summary?.spo2Min?.toStringAsFixed(0) ?? "—"} / ${summary?.spo2Max?.toStringAsFixed(0) ?? "—"}",
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaPillarCard(
                        metricKey: 'skin_temp_delta',
                        label: t("fitbit_vitals_skin_temp_delta"),
                        score: summary?.skinTempC?.abs(),
                        maxScore: 3,
                        icon: Icons.thermostat_rounded,
                        color: const Color(0xFFFF8A00),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: summary?.skinTempC == null
                            ? null
                            : _fmtTemp(summary!.skinTempC!),
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaPillarCard(
                        metricKey: 'breathing_rate',
                        label: t("fitbit_vitals_breathing_rate"),
                        score: summary?.breathingRate,
                        maxScore: 30,
                        icon: Icons.waves_rounded,
                        color: const Color(0xFF9B8CFF),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: summary?.breathingRate == null
                            ? null
                            : summary!.breathingRate!.toStringAsFixed(1),
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaPillarCard(
                        metricKey: 'ecg',
                        label: t("fitbit_vitals_ecg"),
                        score: summary?.ecgSummary == null ? null : 1,
                        maxScore: 1,
                        icon: Icons.monitor_heart_rounded,
                        color: const Color(0xFFE84C4F),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: summary?.ecgSummary == null
                            ? null
                            : _fmtEcg(summary!.ecgSummary!, summary!.ecgAvgHr),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  double? _avgOf(double? a, double? b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return (a + b) / 2;
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
