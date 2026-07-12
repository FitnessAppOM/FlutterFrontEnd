import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_activity_service.dart';

class FitbitDailyActivityDetailPage extends StatelessWidget {
  const FitbitDailyActivityDetailPage({
    super.key,
    required this.summary,
    required this.date,
  });

  final FitbitActivitySummary summary;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;

    return Scaffold(
      appBar: TaqaPageAppBar(
        title: t("fitbit_daily_activity_title"),
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
                _metricCard(
                  metricKey: 'steps',
                  title: t("fitbit_steps_label"),
                  value: summary.steps,
                  goal: summary.goalSteps,
                  unit: "",
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF9B8CFF),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _metricCard(
                  metricKey: 'distance',
                  title: t("fitbit_distance_label"),
                  value: summary.distance,
                  goal: summary.goalDistance,
                  unit: "km",
                  icon: Icons.route_rounded,
                  color: const Color(0xFF35B6FF),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _metricCard(
                  metricKey: 'calories',
                  title: t("fitbit_calories_label"),
                  value: summary.calories,
                  goal: summary.goalCalories,
                  unit: "kcal",
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF8A00),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _metricCard(
                  metricKey: 'floors',
                  title: t("fitbit_floors_label"),
                  value: summary.floors,
                  goal: summary.goalFloors,
                  unit: "",
                  icon: Icons.stairs_rounded,
                  color: const Color(0xFF00BFA6),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _metricCard(
                  metricKey: 'active_minutes',
                  title: t("fitbit_active_minutes_label"),
                  value: summary.activeMinutes,
                  goal: summary.goalActiveMinutes,
                  unit: "min",
                  icon: Icons.timer_rounded,
                  color: const Color(0xFF4CD964),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String metricKey,
    required String title,
    required num? value,
    required num? goal,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final valueText = value == null
        ? null
        : (unit.isEmpty ? _fmt(value) : "${_fmt(value)} $unit");
    final maxScore = (goal != null && goal > 0) ? goal.toDouble() : 1.0;
    return TaqaPillarCard(
      metricKey: metricKey,
      label: title,
      score: value?.toDouble(),
      maxScore: maxScore,
      icon: icon,
      color: color,
      details: const {},
      detailLabels: const {},
      valueDisplay: valueText,
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
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
