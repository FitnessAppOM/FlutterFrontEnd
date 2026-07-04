import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';
import '../services/health/health_recovery_load_service.dart';

class HealthRecoveryLoadDetailPage extends StatelessWidget {
  const HealthRecoveryLoadDetailPage({
    super.key,
    required this.summary,
    required this.date,
  });

  final HealthRecoveryLoadSummary? summary;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final zones = summary?.zones;
    final hasData = summary != null && summary!.hasAnyData;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("health_recovery_title"),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateLabel(),
                SizedBox(height: TaqaUiScale.h(14)),
                if (!hasData)
                  TaqaEmptyCard(
                    title: t("health_recovery_no_healthkit_data"),
                    subtitle: t("common_no_records_in_range"),
                    icon: Icons.favorite_border,
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TaqaLinearMetricCard(
                          title: t("fitbit_heart_resting_hr"),
                          valueText: summary?.restingHeartRate == null
                              ? "—"
                              : "${summary!.restingHeartRate} bpm",
                          subtitle: t("health_recovery_title"),
                          progress: 0,
                          showBar: false,
                          keepBarSpaceWhenHidden: false,
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(12)),
                      Expanded(
                        child: TaqaLinearMetricCard(
                          title: t("health_recovery_hrv"),
                          valueText: summary?.hrvMs == null
                              ? "—"
                              : "${summary!.hrvMs!.toStringAsFixed(0)} ms",
                          subtitle: t("health_recovery_title"),
                          progress: 0,
                          showBar: false,
                          keepBarSpaceWhenHidden: false,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  TaqaLinearMetricCard(
                    title: t("health_recovery_active_minutes"),
                    valueText: summary?.activeMinutes == null
                        ? "—"
                        : "${summary!.activeMinutes} min",
                    subtitle: t("health_recovery_title"),
                    progress: 0,
                    showBar: false,
                    keepBarSpaceWhenHidden: false,
                  ),
                  if (zones != null) ...[
                    SizedBox(height: TaqaUiScale.h(16)),
                    Text(
                      t("health_recovery_zones_title"),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(10),
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.unnamedColor1c1d17,
                        letterSpacing: 0,
                        height: 11 / 10,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Row(
                      children: [
                        Expanded(
                          child: _zoneCard(
                            context,
                            t("health_recovery_zone_out_of_range"),
                            zones.outOfRangeMinutes,
                          ),
                        ),
                        SizedBox(width: TaqaUiScale.w(12)),
                        Expanded(
                          child: _zoneCard(
                            context,
                            t("health_recovery_zone_fat_burn"),
                            zones.fatBurnMinutes,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    Row(
                      children: [
                        Expanded(
                          child: _zoneCard(
                            context,
                            t("health_recovery_zone_cardio"),
                            zones.cardioMinutes,
                          ),
                        ),
                        SizedBox(width: TaqaUiScale.w(12)),
                        Expanded(
                          child: _zoneCard(
                            context,
                            t("health_recovery_zone_peak"),
                            zones.peakMinutes,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _zoneCard(BuildContext context, String title, int minutes) {
    final t = AppLocalizations.of(context).translate;
    return TaqaLinearMetricCard(
      title: title,
      valueText: "$minutes min",
      subtitle: t("health_recovery_zones_title"),
      progress: 0,
      showBar: false,
      keepBarSpaceWhenHidden: false,
    );
  }

  Widget _dateLabel() {
    final label =
        "${_weekdayShort(date.weekday).toUpperCase()}, ${_monthShort(date.month).toUpperCase()} ${date.day}";
    return Text(
      label,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
        fontSize: TaqaUiScale.sp(8),
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 10 / 8,
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
      ),
    );
  }

  String _monthShort(int m) {
    const names = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return names[m - 1];
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday: return "Mon";
      case DateTime.tuesday: return "Tue";
      case DateTime.wednesday: return "Wed";
      case DateTime.thursday: return "Thu";
      case DateTime.friday: return "Fri";
      case DateTime.saturday: return "Sat";
      case DateTime.sunday: return "Sun";
      default: return "";
    }
  }
}
