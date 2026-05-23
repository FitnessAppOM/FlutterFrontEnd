import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../core/account_storage.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/health/steps_service.dart';
import '../services/fitbit/fitbit_steps_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/charts/ranged_bar_chart.dart';

class StepsDetailPage extends StatefulWidget {
  const StepsDetailPage({super.key, this.useFitbit = false, this.initialDate});

  final bool useFitbit;
  final DateTime? initialDate;

  @override
  State<StepsDetailPage> createState() => _StepsDetailPageState();
}

class _StepsDetailPageState extends State<StepsDetailPage> {
  String _range = 'weekly';
  bool _loading = true;
  Map<DateTime, int> _daily = {};
  int? _goal;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int? _selectedBarIndex;
  Timer? _barValueTimer;
  late final DateTime _anchorDate;

  static const _stepsGoalKey = "dashboard_steps_goal";

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

  bool get _isCurrentDayView => _dateOnly(_anchorDate) == _dateOnly(DateTime.now());
  bool get _canManualEdit => _isCurrentDayView && _range == 'weekly';

  @override
  void dispose() {
    _barValueTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _goal = sp.getInt(_stepsGoalKey) ?? 10000;
    });
  }

  Future<void> _editGoal() async {
    if (!_canManualEdit) return;
    final res = await showTaqaValueDialog(
      context: context,
      title: "Edit goal",
      initialValue: (_goal ?? 10000).toString(),
    );
    if (res != null) {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_stepsGoalKey, res);
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
      Map<DateTime, int> data;
      if (widget.useFitbit) {
        data = await FitbitStepsService().fetchDailySteps(
          start: start,
          end: effectiveEnd,
        );
      } else {
        final userId = await AccountStorage.getUserId();
        if (userId == null) {
          if (!mounted) return;
          setState(() {
            _daily = {};
            _rangeStart = null;
            _rangeEnd = null;
            _selectedBarIndex = null;
            _loading = false;
          });
          return;
        }

        final rangeData = await DailyMetricsApi.fetchRange(
          userId: userId,
          start: start,
          end: effectiveEnd,
        );
        data = <DateTime, int>{};
        rangeData.forEach((day, entry) {
          final key = DateTime(day.year, day.month, day.day);
          final steps = entry.steps ?? 0;
          if (steps > 0) {
            data[key] = steps;
          }
        });

        // Apply manual overrides.
        final manual = await StepsService().getManualEntries();
        manual.forEach((day, steps) {
          if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
              !day.isAfter(
                DateTime(
                  effectiveEnd.year,
                  effectiveEnd.month,
                  effectiveEnd.day,
                ),
              )) {
            data[DateTime(day.year, day.month, day.day)] = steps;
          }
        });

        // For current day, prefer HealthKit/Health Connect if no manual override exists.
        final todayKey = today;
        final inRange =
            !todayKey.isBefore(DateTime(start.year, start.month, start.day)) &&
            !todayKey.isAfter(
              DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
            );
        if (inRange && !manual.containsKey(todayKey)) {
          final todaySteps = await StepsService().fetchTodaySteps();
          if (todaySteps > 0) {
            data[todayKey] = todaySteps;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _daily = data;
        _rangeStart = DateTime(start.year, start.month, start.day);
        _rangeEnd = DateTime(end.year, end.month, end.day);
        _selectedBarIndex = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
        _rangeStart = null;
        _rangeEnd = null;
        _selectedBarIndex = null;
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("steps_title"),
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 2.5,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TaqaRangeTab(
                    label: t("range_weekly"),
                    selected: _range == 'weekly',
                    onTap: () => _onRangeTabTap('weekly'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TaqaRangeTab(
                    label: t("range_monthly"),
                    selected: _range == 'monthly',
                    onTap: () => _onRangeTabTap('monthly'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TaqaRangeTab(
                    label: t("range_yearly"),
                    selected: _range == 'yearly',
                    onTap: () => _onRangeTabTap('yearly'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Goal: ${(_goal ?? 10000)}",
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      height: 2.5,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ),
                if (_canManualEdit) ...[
                  TaqaTagButton(
                    icon: Icons.edit_outlined,
                    label: "EDIT GOAL",
                    onTap: _editGoal,
                  ),
                ],
                if (_canManualEdit && !widget.useFitbit) ...[
                  const SizedBox(width: 8),
                  TaqaTagButton(
                    icon: Icons.add,
                    label: "ADD",
                    onTap: _promptManualEntry,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : !_daily.values.any((v) => v > 0)
                  ? _noDataCard(theme)
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
      return _noDataCard(theme);
    }

    final entries = _prepareEntries();
    final maxVal = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final actualMax = maxVal == 0 ? 1.0 : maxVal.toDouble();
    final midVal = actualMax / 2.0;
    const yAxisWidth = 45.0;
    const yAxisGap = 8.0;
    const labelHeight = 16.0;
    const labelGap = 4.0;
    final dense = entries.length > 12;
    final barSpacing = dense ? 2.0 : 4.0;
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _range == 'weekly' ? 'Last 7 days' : _rangeLabel(t),
                style: const TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loading
                    ? t("dash_loading")
                    : 'Avg: ${avg.toStringAsFixed(0)} | Total: $total',
                style: const TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1826),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF35B6FF,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              "${entries[_selectedBarIndex!].detailLabel}  ${entries[_selectedBarIndex!].value} steps",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: TaqaUiColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RangedBarChart(
                  entries: chartEntries,
                  maxValue: actualMax,
                  midValue: midVal,
                  formatValue: _formatStepsAxis,
                  gradient: const [
                    Color(0xFF404040),
                    Color(0xFF1C1D17),
                  ],
                  selectedGradient: const [
                    Color(0xFFE4E93B),
                    Color(0xFFC9CF36),
                  ],
                  selectedIndex: _selectedBarIndex,
                  onBarTap: _onBarTap,
                  showAxisLabels: showLabels,
                  useFixedSlots: useFixedSlots,
                  barSpacing: barSpacing,
                  minBarWidth: 4.0,
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

  List<_StepsBarEntry> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range != 'yearly') {
      final start = _rangeStart;
      final end = _rangeEnd;
      if (start == null || end == null) {
        final entries = _daily.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .map(
              (e) => _StepsBarEntry(
                axisLabel: "",
                detailLabel: "${e.key.day} ${_monthShort(e.key.month)}",
                value: e.value,
              ),
            )
            .toList();
      }
      final items = <_StepsBarEntry>[];
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      final lastDay = last.day;
      while (!cursor.isAfter(last)) {
        final key = DateTime(cursor.year, cursor.month, cursor.day);
        String label = "";
        if (_range == 'weekly') {
          label = _weekdayShort(cursor.weekday);
        } else {
          final dayNum = cursor.day;
          final midDay = (lastDay / 2).round();
          final showLabel =
              dayNum == 1 || dayNum == midDay || dayNum == lastDay;
          label = showLabel ? dayNum.toString() : "";
        }
        final detail = _range == 'weekly'
            ? "${_weekdayShort(cursor.weekday)}, ${cursor.day} ${_monthShort(cursor.month)}"
            : "${cursor.day} ${_monthShort(cursor.month)}";
        items.add(
          _StepsBarEntry(
            axisLabel: label,
            detailLabel: detail,
            value: _daily[key] ?? 0,
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      return items;
    }

    final start = _rangeStart;
    final end = _rangeEnd;
    if (start == null || end == null) return [];

    final Map<String, List<int>> buckets = {};
    _daily.forEach((day, steps) {
      final label = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      buckets.putIfAbsent(label, () => []).add(steps);
    });

    final entries = <_StepsBarEntry>[];
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      final values = buckets[key] ?? const <int>[];
      final avg = values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) ~/ values.length;
      entries.add(
        _StepsBarEntry(
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

  Widget _noDataCard(ThemeData theme) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        AppLocalizations.of(context).translate("no_steps_range"),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _rangeLabel(String Function(String) t) {
    switch (_range) {
      case 'monthly':
        final ref = _rangeStart ?? _anchorDate;
        final days = DateTime(ref.year, ref.month + 1, 0).day;
        return "Last $days days";
      case 'yearly':
        return t("range_last_year");
      case 'weekly':
      default:
        return t("range_last7");
    }
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

  String _formatStepsAxis(double value) {
    if (value >= 1000) {
      final k = value / 1000.0;
      final digits = k >= 10 ? 0 : 1;
      return "${k.toStringAsFixed(digits)}k";
    }
    return value.toStringAsFixed(0);
  }

  int _todaySteps() {
    final now = DateTime.now();
    final key = DateTime(now.year, now.month, now.day);
    return _daily[key] ?? 0;
  }

  Future<void> _promptManualEntry() async {
    if (!_canManualEdit) return;
    final result = await showTaqaValueDialog(
      context: context,
      title: "Add steps",
      initialValue: _todaySteps() > 0 ? _todaySteps().toString() : '',
    );
    if (result != null) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await StepsService().saveManualEntry(day, result);
      if (mounted) {
        _loadRange();
      }
    }
  }

}

class _StepsBarEntry {
  const _StepsBarEntry({
    required this.axisLabel,
    required this.detailLabel,
    required this.value,
  });

  final String axisLabel;
  final String detailLabel;
  final int value;
}
