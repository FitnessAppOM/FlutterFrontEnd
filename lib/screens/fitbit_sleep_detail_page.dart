import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/components/taqa_progress_widget_card.dart';
import '../TaqaUI/components/taqa_sleep_stages_wide_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_sleep_service.dart';

class FitbitSleepDetailPage extends StatelessWidget {
  const FitbitSleepDetailPage({
    super.key,
    required this.summary,
    this.sleepScore,
    required this.date,
  });

  final FitbitSleepSummary? summary;
  final int? sleepScore;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final logs = summary?.logs ?? const [];
    final stageEntries = _orderedStages(summary?.stageMinutes ?? const {});
    final asleep = summary?.totalMinutesAsleep;
    final inBed = summary?.totalTimeInBed;
    final goal = summary?.sleepGoalMinutes;
    final progress = (asleep != null && goal != null && goal > 0)
        ? (asleep / goal).clamp(0.0, 1.0)
        : 0.0;
    final hasData = summary != null &&
        (asleep != null || inBed != null || sleepScore != null);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_sleep_title"),
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
                _DateLabel(date: date),
                SizedBox(height: TaqaUiScale.h(14)),
                if (!hasData)
                  TaqaEmptyCard(
                    title: t("dash_no_sleep_data"),
                    subtitle: t("common_no_records_in_range"),
                    icon: Icons.bedtime_outlined,
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TaqaProgressWidgetCard(
                          title: t("sleep_total_sleep_title"),
                          valueText: asleep == null ? "—" : _fmtMinutes(asleep),
                          goalText: goal == null
                              ? "—"
                              : t("common_goal_value").replaceAll(
                                  "{value}",
                                  _fmtMinutes(goal),
                                ),
                          progress: progress,
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(12)),
                      Expanded(
                        child: TaqaProgressWidgetCard(
                          title: t("sleep_time_in_bed_title"),
                          valueText: inBed == null ? "—" : _fmtMinutes(inBed),
                          goalText: t("fitbit_sleep_score"),
                          progress: sleepScore == null
                              ? 0.0
                              : (sleepScore! / 100).clamp(0.0, 1.0),
                          showArc: sleepScore != null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  TaqaLinearMetricCard(
                    title: t("fitbit_sleep_score"),
                    valueText: sleepScore == null ? "—" : "$sleepScore%",
                    subtitle: t("fitbit_sleep_title"),
                    progress: sleepScore == null ? 0.0 : sleepScore! / 100,
                    showBar: sleepScore != null,
                  ),
                  if (stageEntries.isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(12)),
                    TaqaSleepStagesWideCard(
                      title: t("sleep_total_sleep_title"),
                      centerLabel: t("sleep_stages_label"),
                      lightPct: _stagePct(stageEntries, "light"),
                      deepPct: _stagePct(stageEntries, "deep"),
                      remPct: _stagePct(stageEntries, "rem"),
                    ),
                  ],
                  if (logs.isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(16)),
                    Text(
                      t("fitbit_sleep_logs_title"),
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
                    for (final log in logs) _LogTile(log: log),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _stagePct(List<MapEntry<String, int>> entries, String key) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total <= 0) return 0.0;
    final match = entries.where((e) => e.key.toLowerCase() == key).toList();
    if (match.isEmpty) return 0.0;
    return match.first.value / total;
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "${h}h ${m}m";
  }

  List<MapEntry<String, int>> _orderedStages(Map<String, int> stages) {
    const order = <String, int>{
      "deep": 0,
      "light": 1,
      "rem": 2,
      "wake": 3,
      "awake": 3,
      "asleep": 4,
      "restless": 5,
    };
    final entries = stages.entries.where((e) => e.value > 0).toList();
    entries.sort((a, b) {
      final aKey = a.key.toLowerCase();
      final bKey = b.key.toLowerCase();
      final oa = order[aKey] ?? 999;
      final ob = order[bKey] ?? 999;
      if (oa != ob) return oa.compareTo(ob);
      return aKey.compareTo(bKey);
    });
    return entries;
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final FitbitSleepLog log;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final start = log.start?.toLocal();
    final end = log.end?.toLocal();
    final startLabel = start == null
        ? "—"
        : "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    final endLabel = end == null
        ? "—"
        : "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    final duration = log.minutesAsleep == null ? "—" : "${log.minutesAsleep} min";
    final main = log.isMainSleep == true
        ? t("fitbit_sleep_log_main_sleep")
        : t("fitbit_sleep_log_nap_other");

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
              "$startLabel → $endLabel",
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(8)),
          Text(
            main,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
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
