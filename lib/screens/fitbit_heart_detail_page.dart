import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';

class FitbitHeartDetailPage extends StatelessWidget {
  const FitbitHeartDetailPage({
    super.key,
    required this.restingHr,
    required this.hrvRmssd,
    required this.vo2Max,
    required this.zones,
    required this.date,
  });

  final int? restingHr;
  final double? hrvRmssd;
  final String? vo2Max;
  final List<dynamic> zones;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_heart_title"),
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
                Row(
                  children: [
                    Expanded(
                      child: TaqaLinearMetricCard(
                        title: t("fitbit_heart_resting_hr"),
                        valueText: restingHr == null ? "—" : "$restingHr bpm",
                        subtitle: t("fitbit_heart_title"),
                        progress: 0,
                        showBar: false,
                        keepBarSpaceWhenHidden: false,
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: TaqaLinearMetricCard(
                        title: t("fitbit_heart_hrv_rmssd"),
                        valueText: hrvRmssd == null
                            ? "—"
                            : "${hrvRmssd!.toStringAsFixed(0)} ms",
                        subtitle: t("fitbit_heart_title"),
                        progress: 0,
                        showBar: false,
                        keepBarSpaceWhenHidden: false,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                TaqaLinearMetricCard(
                  title: t("fitbit_heart_vo2max"),
                  valueText: vo2Max == null || vo2Max!.isEmpty ? "—" : vo2Max!,
                  subtitle: t("fitbit_heart_title"),
                  progress: 0,
                  showBar: false,
                  keepBarSpaceWhenHidden: false,
                ),
                if (zones.isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(16)),
                  Text(
                    t("fitbit_heart_zones_title"),
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
                  for (final z in zones) _ZoneTile(zone: z),
                ],
              ],
            ),
          ),
        ),
      ),
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

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone});

  final dynamic zone;

  @override
  Widget build(BuildContext context) {
    String name = AppLocalizations.of(context).translate("common_zone");
    String range = "—";
    String minutes = "—";
    if (zone is Map) {
      final z = zone as Map;
      name = z["name"]?.toString() ?? name;
      final min = z["min"]?.toString();
      final max = z["max"]?.toString();
      if (min != null && max != null) range = "$min-$max bpm";
      final mins = z["minutes"]?.toString();
      if (mins != null) minutes = "$mins min";
    }
    return Container(
      margin: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
          Text(
            range,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(width: TaqaUiScale.w(10)),
          Text(
            minutes,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ],
      ),
    );
  }
}
