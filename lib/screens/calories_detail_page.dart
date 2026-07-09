import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../core/account_storage.dart';
import '../services/diet/calories_service.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/training/training_calories_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/charts/ranged_bar_chart.dart';

class CaloriesDetailPage extends StatefulWidget {
  const CaloriesDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<CaloriesDetailPage> createState() => _CaloriesDetailPageState();
}

class _CaloriesDetailPageState extends State<CaloriesDetailPage> {
  String _range = 'weekly';
  bool _loading = true;
  Map<DateTime, int> _daily = {};
  int? _goal;
  int? _selectedBarIndex;
  Timer? _barValueTimer;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late final DateTime _anchorDate;

  static const _caloriesGoalKey = "dashboard_calories_goal";

  @override
  void initState() {
    super.initState();
    _anchorDate = _resolvedAnchorDate(widget.initialDate);
    _loadGoal();
    _loadRange();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _resolvedAnchorDate(DateTime? date) {
    final today = _dateOnly(DateTime.now());
    final requested = _dateOnly(date ?? today);
    return requested.isAfter(today) ? today : requested;
  }

  bool get _isCurrentDayView =>
      _dateOnly(_anchorDate) == _dateOnly(DateTime.now());
  bool get _canManualEdit => _isCurrentDayView && _range == 'weekly';

  @override
  void dispose() {
    _barValueTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _goal = sp.getInt(_caloriesGoalKey) ?? 500;
    });
  }

  Future<void> _editGoal() async {
    if (!_canManualEdit) return;
    final res = await showTaqaValueDialog(
      context: context,
      title: AppLocalizations.of(context).translate("common_edit_goal_title"),
      initialValue: (_goal ?? 500).toString(),
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_caloriesGoalKey, res);
      if (!mounted) return;
      setState(() => _goal = res);
    }
  }

  Future<void> _loadRange() async {
    setState(() => _loading = true);
    try {
      final today = _dateOnly(DateTime.now());
      final reference = _anchorDate.isAfter(today) ? today : _anchorDate;
      DateTime start;
      DateTime end;
      switch (_range) {
        case 'monthly':
          start = DateTime(reference.year, reference.month, 1);
          end = DateTime(reference.year, reference.month + 1, 0);
          break;
        case 'yearly':
          start = DateTime(reference.year, 1, 1);
          end = DateTime(reference.year, 12, 31);
          break;
        case 'weekly':
        default:
          start = reference.subtract(Duration(days: reference.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
      }
      final effectiveEnd = today.isBefore(end) ? today : end;
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _daily = {};
          _selectedBarIndex = null;
          _rangeStart = start;
          _rangeEnd = end;
          _loading = false;
        });
        return;
      }

      final rangeData = await DailyMetricsApi.fetchRange(
        userId: userId,
        start: start,
        end: effectiveEnd,
      );
      final data = <DateTime, int>{};
      rangeData.forEach((day, entry) {
        final key = DateTime(day.year, day.month, day.day);
        final calories = entry.calories ?? 0;
        if (calories > 0) {
          data[key] = calories;
        }
      });

      // Apply manual overrides (all days).
      final manual = await CaloriesService().getManualEntries();
      manual.forEach((day, calories) {
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(
              DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
            )) {
          data[DateTime(day.year, day.month, day.day)] = calories;
        }
      });
      // Apply manual total display overrides (all days); these win over DB/health values.
      final manualTotals = await CaloriesService()
          .getManualTotalDisplayEntries();
      manualTotals.forEach((day, calories) {
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(
              DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
            )) {
          data[DateTime(day.year, day.month, day.day)] = calories;
        }
      });

      // For current day, prefer HealthKit/Health Connect (unless manual override exists).
      final todayKey = today;
      final inRange =
          !todayKey.isBefore(DateTime(start.year, start.month, start.day)) &&
          !todayKey.isAfter(
            DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
          );
      if (inRange && manualTotals.containsKey(todayKey)) {
        data[todayKey] = manualTotals[todayKey]!;
      } else if (inRange && manual.containsKey(todayKey)) {
        final trainingCalories = await TrainingCaloriesService()
            .fetchEstimatedCaloriesForDay(todayKey);
        if (trainingCalories > 0) {
          data[todayKey] = (data[todayKey] ?? 0) + trainingCalories;
        }
      } else if (inRange && !manual.containsKey(todayKey)) {
        final baseCalories = await CaloriesService().fetchTodayCalories();
        final trainingCalories = await TrainingCaloriesService()
            .fetchEstimatedCaloriesForDay(todayKey);
        final todayCalories = baseCalories + trainingCalories;
        if (todayCalories > 0) {
          data[todayKey] = todayCalories;
        }
      }
      if (!mounted) return;
      setState(() {
        _daily = data;
        _selectedBarIndex = null;
        _rangeStart = start;
        _rangeEnd = end;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
        _selectedBarIndex = null;
        _rangeStart = null;
        _rangeEnd = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final theme = Theme.of(context);
    final total = _daily.values.fold<int>(0, (a, b) => a + b);
    final avg = _daily.isEmpty ? 0.0 : total / _daily.length;
    final bars = _buildBars(theme, t, avg, total);

    return Scaffold(
      appBar: TaqaPageAppBar(title: t("calories_title")),
      resizeToAvoidBottomInset: false,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: Padding(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaRangeTab(
                    label: t("range_weekly"),
                    selected: _range == 'weekly',
                    onTap: () => _onRangeTabTap('weekly'),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(15)),
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaRangeTab(
                    label: t("range_monthly"),
                    selected: _range == 'monthly',
                    onTap: () => _onRangeTabTap('monthly'),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(15)),
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaRangeTab(
                    label: t("range_yearly"),
                    selected: _range == 'yearly',
                    onTap: () => _onRangeTabTap('yearly'),
                  ),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(19)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    t(
                      "calories_goal_btn",
                    ).replaceAll("{value}", "${_goal ?? 500}"),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(25),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ),
                if (_canManualEdit) ...[
                  TaqaTagButton(
                    icon: Icons.edit_outlined,
                    label: t("common_edit_goal_button"),
                    onTap: _editGoal,
                  ),
                  SizedBox(width: TaqaUiScale.w(8)),
                  TaqaTagButton(
                    icon: Icons.add,
                    label: t("common_add_button"),
                    onTap: _promptManualEntry,
                  ),
                ],
              ],
            ),
            SizedBox(height: TaqaUiScale.h(19)),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : !_daily.values.any((v) => v > 0)
                  ? TaqaEmptyCard(
                      title: t("dash_no_calories_data"),
                      subtitle: t("common_no_records_in_range"),
                      icon: Icons.local_fire_department_outlined,
                    )
                  : bars,
            ),
          ],
        ),
      ),
    );
  }

  void _onRangeTabTap(String value) {
    if (_range == value) return;
    _barValueTimer?.cancel();
    setState(() {
      _range = value;
      _selectedBarIndex = null;
    });
    _loadRange();
  }

  Widget _buildBars(
    ThemeData theme,
    String Function(String) t,
    double avg,
    int total,
  ) {
    if (!_daily.values.any((v) => v > 0)) {
      return TaqaEmptyCard(
        title: t("dash_no_calories_data"),
        subtitle: t("common_no_records_in_range"),
        icon: Icons.local_fire_department_outlined,
      );
    }

    final entries = _prepareEntries();
    final maxVal = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final actualMax = maxVal == 0 ? 1.0 : maxVal.toDouble();
    final midVal = actualMax / 2.0;
    final yAxisWidth = TaqaUiScale.w(45);
    final yAxisGap = TaqaUiScale.w(8);
    final labelHeight = TaqaUiScale.h(16);
    final labelGap = TaqaUiScale.h(4);
    final dense = entries.length > 12;
    final barSpacing = dense ? TaqaUiScale.w(2) : TaqaUiScale.w(4);
    final useFixedSlots = dense || _range != 'weekly';
    final showLabels = _range != 'monthly';
    final chartEntries = entries
        .map(
          (e) => RangedBarChartEntry(
            axisLabel: e.axisLabel,
            value: e.value.toDouble(),
          ),
        )
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiScale.radius(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _range == 'weekly' ? t("range_last7") : _rangeLabel(t),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(5)),
              Text(
                _loading
                    ? t("dash_loading")
                    : t("common_avg_total")
                          .replaceAll("{avg}", avg.toStringAsFixed(0))
                          .replaceAll("{total}", "$total"),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(10),
                  fontWeight: FontWeight.w400,
                  height: 11 / 10,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(10)),
              SizedBox(
                height: TaqaUiScale.h(34),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        (_selectedBarIndex == null ||
                            _selectedBarIndex! < 0 ||
                            _selectedBarIndex! >= entries.length)
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey<int>(_selectedBarIndex!),
                            padding: TaqaUiScale.insetsLTRB(12, 7, 12, 7),
                            decoration: BoxDecoration(
                              color: TaqaUiColors.charcoal,
                              borderRadius: TaqaUiScale.radius(10),
                              border: Border.all(
                                color: TaqaUiColors.lime.withValues(
                                  alpha: 0.45,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              "${entries[_selectedBarIndex!].detailLabel}  ${entries[_selectedBarIndex!].value} ${t("dash_unit_kcal")}",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: TaqaUiScale.sp(10),
                                fontWeight: FontWeight.w700,
                                color: TaqaUiColors.white,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(10)),
              Expanded(
                child: RangedBarChart(
                  entries: chartEntries,
                  maxValue: actualMax,
                  midValue: midVal,
                  formatValue: _fmtCalories,
                  gradient: const [Color(0xFF404040), Color(0xFF1C1D17)],
                  selectedGradient: const [
                    Color(0xFFE4E93B),
                    Color(0xFFC9CF36),
                  ],
                  selectedIndex: _selectedBarIndex,
                  onBarTap: _onBarTap,
                  showAxisLabels: showLabels,
                  useFixedSlots: useFixedSlots,
                  barSpacing: barSpacing,
                  minBarWidth: TaqaUiScale.w(4),
                  yAxisWidth: yAxisWidth,
                  yAxisGap: yAxisGap,
                  labelHeight: labelHeight,
                  labelGap: labelGap,
                  axisTextColor: TaqaUiColors.unnamedColor1c1d17,
                  labelTextColor: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtCalories(num value) {
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}k";
    }
    return value.toStringAsFixed(0);
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

  String _monthShort(int month) {
    switch (month) {
      case 1:
        return "Jan";
      case 2:
        return "Feb";
      case 3:
        return "Mar";
      case 4:
        return "Apr";
      case 5:
        return "May";
      case 6:
        return "Jun";
      case 7:
        return "Jul";
      case 8:
        return "Aug";
      case 9:
        return "Sep";
      case 10:
        return "Oct";
      case 11:
        return "Nov";
      case 12:
        return "Dec";
      default:
        return "";
    }
  }

  List<_CaloriesBarEntry> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range == 'weekly' || _range == 'monthly') {
      final start = _rangeStart;
      final end = _rangeEnd;
      if (start != null && end != null) {
        final items = <_CaloriesBarEntry>[];
        var cursor = DateTime(start.year, start.month, start.day);
        final last = DateTime(end.year, end.month, end.day);
        final lastDay = last.day;
        final midDay = (lastDay / 2).round();
        while (!cursor.isAfter(last)) {
          final key = DateTime(cursor.year, cursor.month, cursor.day);
          String label = "";
          if (_range == 'weekly') {
            label = _weekdayShort(cursor.weekday);
          } else {
            final dayNum = cursor.day;
            final showLabel =
                dayNum == 1 || dayNum == midDay || dayNum == lastDay;
            label = showLabel ? dayNum.toString() : "";
          }
          items.add(
            _CaloriesBarEntry(
              axisLabel: label,
              detailLabel: _range == 'weekly'
                  ? "$label ${cursor.month}/${cursor.day}"
                  : "${cursor.month}/${cursor.day}",
              value: _daily[key] ?? 0,
            ),
          );
          cursor = cursor.add(const Duration(days: 1));
        }
        return items;
      }
    }
    if (_range != 'yearly') {
      final entries = _daily.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return entries
          .map(
            (e) => _CaloriesBarEntry(
              axisLabel: "",
              detailLabel: "${e.key.month}/${e.key.day}",
              value: e.value,
            ),
          )
          .toList();
    }

    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) return [];

    final Map<String, List<int>> buckets = {};
    _daily.forEach((day, calories) {
      final label = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      buckets.putIfAbsent(label, () => []).add(calories);
    });

    final entries = <_CaloriesBarEntry>[];
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      final values = buckets[key] ?? const <int>[];
      final avg = values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) ~/ values.length;
      entries.add(
        _CaloriesBarEntry(
          axisLabel: _monthShort(cursor.month),
          detailLabel: "${_monthShort(cursor.month)} ${cursor.year}",
          value: avg,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return entries;
  }

  void _onBarTap(int index) {
    _barValueTimer?.cancel();
    if (!mounted) return;
    setState(() => _selectedBarIndex = index);
    _barValueTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _selectedBarIndex = null);
    });
  }

  String _rangeLabel(String Function(String) t) {
    switch (_range) {
      case 'monthly':
        final ref = _rangeStart ?? _anchorDate;
        final days = DateTime(ref.year, ref.month + 1, 0).day;
        return t("range_last_n_days").replaceAll("{n}", "$days");
      case 'yearly':
        return t("range_last_year");
      case 'weekly':
      default:
        return t("range_last7");
    }
  }

  int _todayCalories() {
    final now = DateTime.now();
    final key = DateTime(now.year, now.month, now.day);
    return _daily[key] ?? 0;
  }

  Future<void> _promptManualEntry() async {
    if (!_canManualEdit) return;
    final result = await showTaqaValueDialog(
      context: context,
      title: AppLocalizations.of(
        context,
      ).translate("calories_add_dialog_title"),
      initialValue: _todayCalories() > 0 ? _todayCalories().toString() : '',
    );
    if (result != null) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await CaloriesService().saveManualTotalDisplayEntry(day, result);
      if (mounted) {
        _loadRange();
      }
    }
  }
}

class _CaloriesBarEntry {
  const _CaloriesBarEntry({
    required this.axisLabel,
    required this.detailLabel,
    required this.value,
  });

  final String axisLabel;
  final String detailLabel;
  final int value;
}
