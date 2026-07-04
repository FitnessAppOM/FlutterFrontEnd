import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_daily_activity_title"),
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
                      child: _metricCard(
                        title: t("fitbit_steps_label"),
                        value: summary.steps,
                        goal: summary.goalSteps,
                        unit: "",
                        goalPrefix: t("fitbit_goal_label"),
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: _metricCard(
                        title: t("fitbit_distance_label"),
                        value: summary.distance,
                        goal: summary.goalDistance,
                        unit: "km",
                        goalPrefix: t("fitbit_goal_label"),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: t("fitbit_calories_label"),
                        value: summary.calories,
                        goal: summary.goalCalories,
                        unit: "kcal",
                        goalPrefix: t("fitbit_goal_label"),
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(12)),
                    Expanded(
                      child: _metricCard(
                        title: t("fitbit_floors_label"),
                        value: summary.floors,
                        goal: summary.goalFloors,
                        unit: "",
                        goalPrefix: t("fitbit_goal_label"),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _metricCard(
                  title: t("fitbit_active_minutes_label"),
                  value: summary.activeMinutes,
                  goal: summary.goalActiveMinutes,
                  unit: "min",
                  goalPrefix: t("fitbit_goal_label"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required num? value,
    required num? goal,
    required String unit,
    required String goalPrefix,
  }) {
    final valueText = value == null
        ? "—"
        : (unit.isEmpty ? _fmt(value) : "${_fmt(value)} $unit");
    final progress = (value != null && goal != null && goal > 0)
        ? (value / goal).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final goalLabel = goal == null ? "—" : "${_fmt(goal)} $unit".trim();
    return TaqaLinearMetricCard(
      title: title,
      valueText: valueText,
      subtitle: goalPrefix.replaceAll("{value}", goalLabel),
      progress: progress,
      showBar: goal != null,
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
