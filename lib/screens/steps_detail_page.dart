import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/account_storage.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/health/steps_service.dart';
import '../services/fitbit/fitbit_steps_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/charts/ranged_bar_chart.dart';

class StepsDetailPage extends StatefulWidget {
  const StepsDetailPage({super.key, this.useFitbit = false});

  final bool useFitbit;

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

  static const _stepsGoalKey = "dashboard_steps_goal";

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadRange();
  }

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
    final controller = TextEditingController(text: (_goal ?? 10000).toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Steps goal",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Steps per day",
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
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
      final now = DateTime.now();
      DateTime start;
      DateTime end;
      switch (_range) {
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          start = now.subtract(const Duration(days: 365));
          end = now;
          break;
        case 'weekly':
        default:
          final today = DateTime(now.year, now.month, now.day);
          start = today.subtract(Duration(days: today.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
      }
      final effectiveEnd = now.isBefore(end) ? now : end;
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
        final todayKey = DateTime(now.year, now.month, now.day);
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
    final avg = _daily.isEmpty ? 0 : total / _daily.length;
    final bars = _buildBars(theme);

    return Scaffold(
      appBar: AppBar(
        title: Text(t("steps_title")),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('weekly', t("range_weekly")),
                _chip('monthly', t("range_monthly")),
                _chip('yearly', t("range_yearly")),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!widget.useFitbit) ...[
                  ElevatedButton(
                    onPressed: _promptManualEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(t("steps_edit_today")),
                  ),
                  const SizedBox(width: 10),
                ],
                ElevatedButton(
                  onPressed: _editGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardDark,
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t(
                      "steps_goal_btn",
                    ).replaceAll("{value}", (_goal ?? 10000).toString()),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _rangeLabel(t),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loading
                  ? t("dash_loading")
                  : 'Avg: ${avg.toStringAsFixed(0)} | Total: $total',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
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

  Widget _chip(String value, String label) {
    final selected = _range == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _barValueTimer?.cancel();
        setState(() {
          _range = value;
          _selectedBarIndex = null;
        });
        _loadRange();
      },
      selectedColor: AppColors.accent.withValues(alpha: 0.25),
      backgroundColor: AppColors.cardDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBars(ThemeData theme) {
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
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                                color: Colors.white,
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
                  gradient: const [Color(0xFF35B6FF), Color(0xFF9B8CFF)],
                  selectedGradient: const [
                    Color(0xFF6BE1FF),
                    Color(0xFFB7A9FF),
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
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        AppLocalizations.of(context).translate("no_steps_range"),
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _rangeLabel(String Function(String) t) {
    switch (_range) {
      case 'monthly':
        final ref = _rangeStart ?? DateTime.now();
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
    final controller = TextEditingController(
      text: _todaySteps() > 0 ? _todaySteps().toString() : '',
    );
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Edit today's steps",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "e.g. 8500",
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'reset'),
              child: const Text("Reset"),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val >= 0) {
                  Navigator.pop(ctx, val);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result == 'reset') {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await StepsService().clearManualEntry(day);
      if (mounted) {
        _loadRange();
      }
      return;
    }

    if (result is int) {
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
