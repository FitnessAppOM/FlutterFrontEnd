import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
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
      appBar: TaqaPageAppBar(
        title: t("fitbit_heart_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
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
                TaqaPillarCard(
                  metricKey: 'resting_hr',
                  label: t("fitbit_heart_resting_hr"),
                  score: restingHr?.toDouble(),
                  maxScore: 100,
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFE84C4F),
                  details: const {},
                  detailLabels: const {},
                  valueDisplay: restingHr == null ? null : "$restingHr bpm",
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                TaqaPillarCard(
                  metricKey: 'hrv',
                  label: t("fitbit_heart_hrv_rmssd"),
                  score: hrvRmssd,
                  maxScore: 150,
                  icon: Icons.timeline_rounded,
                  color: const Color(0xFF9B8CFF),
                  details: const {},
                  detailLabels: const {},
                  valueDisplay: hrvRmssd == null
                      ? null
                      : "${hrvRmssd!.toStringAsFixed(0)} ms",
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                TaqaPillarCard(
                  metricKey: 'vo2max',
                  label: t("fitbit_heart_vo2max"),
                  score: (vo2Max == null || vo2Max!.isEmpty) ? null : 1,
                  maxScore: 1,
                  icon: Icons.directions_run_rounded,
                  color: const Color(0xFF35B6FF),
                  details: const {},
                  detailLabels: const {},
                  valueDisplay: vo2Max,
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
                  for (int i = 0; i < zones.length; i++) ...[
                    _ZoneTile(zone: zones[i], maxMinutes: _maxZoneMinutes()),
                    if (i < zones.length - 1) SizedBox(height: TaqaUiScale.h(12)),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _maxZoneMinutes() {
    double max = 0;
    for (final z in zones) {
      if (z is Map) {
        final mins = z["minutes"];
        if (mins is num && mins.toDouble() > max) max = mins.toDouble();
      }
    }
    return max <= 0 ? 1 : max;
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
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[m - 1];
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, required this.maxMinutes});

  final dynamic zone;
  final double maxMinutes;

  @override
  Widget build(BuildContext context) {
    String name = AppLocalizations.of(context).translate("common_zone");
    String range = "—";
    double? minutes;
    if (zone is Map) {
      final z = zone as Map;
      name = z["name"]?.toString() ?? name;
      final min = z["min"]?.toString();
      final max = z["max"]?.toString();
      if (min != null && max != null) range = "$min-$max bpm";
      final mins = z["minutes"];
      if (mins is num) minutes = mins.toDouble();
    }

    return TaqaPillarCard(
      metricKey: 'heart_zone_${name.toLowerCase().replaceAll(' ', '_')}',
      label: range == "—" ? name : "$name ($range)",
      score: minutes,
      maxScore: maxMinutes,
      icon: _zoneIcon(name),
      color: _zoneColor(name),
      details: const {},
      detailLabels: const {},
      valueDisplay: minutes == null
          ? null
          : "${minutes.toStringAsFixed(0)} min",
    );
  }

  IconData _zoneIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('peak')) return Icons.whatshot_rounded;
    if (n.contains('cardio')) return Icons.directions_run_rounded;
    if (n.contains('fat')) return Icons.local_fire_department_rounded;
    return Icons.bedtime_rounded;
  }

  Color _zoneColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('peak')) return const Color(0xFFE84C4F);
    if (n.contains('cardio')) return const Color(0xFFFF8A00);
    if (n.contains('fat')) return const Color(0xFF4CD964);
    return const Color(0xFF35B6FF);
  }
}
