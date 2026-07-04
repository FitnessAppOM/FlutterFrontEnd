import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_vitals_service.dart';

class FitbitVitalsDetailPage extends StatelessWidget {
  const FitbitVitalsDetailPage({super.key, required this.summary});

  final FitbitVitalsSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final hasData = summary != null &&
        (summary!.spo2Percent != null ||
            summary!.skinTempC != null ||
            summary!.breathingRate != null ||
            summary!.ecgSummary != null);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_vitals_title"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TaqaLinearMetricCard(
                              title: t("fitbit_vitals_spo2_avg"),
                              valueText: summary?.spo2Percent == null
                                  ? "—"
                                  : "${summary!.spo2Percent!.toStringAsFixed(0)}%",
                              subtitle: t("fitbit_vitals_title"),
                              progress: 0,
                              showBar: false,
                              keepBarSpaceWhenHidden: false,
                            ),
                          ),
                          SizedBox(width: TaqaUiScale.w(12)),
                          Expanded(
                            child: TaqaLinearMetricCard(
                              title: t("fitbit_vitals_spo2_minmax"),
                              valueText: (summary?.spo2Min == null &&
                                      summary?.spo2Max == null)
                                  ? "—"
                                  : "${summary?.spo2Min?.toStringAsFixed(0) ?? "—"} / ${summary?.spo2Max?.toStringAsFixed(0) ?? "—"}",
                              subtitle: t("fitbit_vitals_title"),
                              progress: 0,
                              showBar: false,
                              keepBarSpaceWhenHidden: false,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      Row(
                        children: [
                          Expanded(
                            child: TaqaLinearMetricCard(
                              title: t("fitbit_vitals_skin_temp_delta"),
                              valueText: summary?.skinTempC == null
                                  ? "—"
                                  : _fmtTemp(summary!.skinTempC!),
                              subtitle: t("fitbit_vitals_title"),
                              progress: 0,
                              showBar: false,
                              keepBarSpaceWhenHidden: false,
                            ),
                          ),
                          SizedBox(width: TaqaUiScale.w(12)),
                          Expanded(
                            child: TaqaLinearMetricCard(
                              title: t("fitbit_vitals_breathing_rate"),
                              valueText: summary?.breathingRate == null
                                  ? "—"
                                  : summary!.breathingRate!.toStringAsFixed(1),
                              subtitle: t("fitbit_vitals_title"),
                              progress: 0,
                              showBar: false,
                              keepBarSpaceWhenHidden: false,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaLinearMetricCard(
                        title: t("fitbit_vitals_ecg"),
                        valueText: summary?.ecgSummary == null
                            ? "—"
                            : _fmtEcg(summary!.ecgSummary!, summary?.ecgAvgHr),
                        subtitle: t("fitbit_vitals_title"),
                        progress: 0,
                        showBar: false,
                        keepBarSpaceWhenHidden: false,
                      ),
                    ],
                  ),
          ),
        ),
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
