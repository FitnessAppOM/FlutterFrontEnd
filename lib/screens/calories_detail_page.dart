import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/account_storage.dart';
import '../services/diet/calories_service.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/training/training_calories_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/ranged_bar_chart.dart';
import '../localization/app_localizations.dart';

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
      _goal = sp.getInt(_caloriesGoalKey) ?? 500;
    });
  }

  Future<void> _editGoal() async {
    if (!_canManualEdit) return;
    final controller = TextEditingController(text: (_goal ?? 500).toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Calories burn goal",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "kcal per day",
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
          start = reference.subtract(const Duration(days: 365));
          end = reference;
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
    final avg = _daily.isEmpty ? 0 : total / _daily.length;
    final bars = _buildBars(theme);

    return Scaffold(
      appBar: AppBar(
        title: Text(t("calories_title")),
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
                if (_canManualEdit) ...[
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
                    child: Text(t("calories_edit_today")),
                  ),
                  const SizedBox(width: 10),
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
                        "calories_goal_btn",
                      ).replaceAll("{value}", (_goal ?? 500).toString()),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
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
                  : 'Avg: ${avg.toStringAsFixed(0)} kcal | Total: $total kcal',
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
    final safeMax = maxVal == 0 ? 1 : maxVal;
    final isDense = _range != 'weekly';
    final barSpacing = isDense ? 2.0 : 4.0;
    const yAxisWidth = 42.0;
    const yAxisGap = 8.0;
    final avgVal = entries.isEmpty
        ? 0.0
        : entries.fold<double>(0, (m, e) => m + e.value) / entries.length;
    final showLabels = _range == 'weekly' || _range == 'yearly';
    final chartEntries = entries
        .map(
          (e) => RangedBarChartEntry(
            axisLabel: e.axisLabel,
            value: e.value.toDouble(),
          ),
        )
        .toList();

    return Container(
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
                          "${entries[_selectedBarIndex!].detailLabel}  ${entries[_selectedBarIndex!].value} kcal",
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
              maxValue: safeMax.toDouble(),
              midValue: avgVal,
              formatValue: _fmtCalories,
              gradient: const [Color(0xFFFF8A00), Color(0xFFFFC266)],
              selectedGradient: const [Color(0xFFFFC266), Color(0xFFFFE1A6)],
              selectedIndex: _selectedBarIndex,
              onBarTap: _onBarTap,
              showAxisLabels: showLabels,
              useFixedSlots: isDense,
              barSpacing: barSpacing,
              minBarWidth: 0.0,
              yAxisWidth: yAxisWidth,
              yAxisGap: yAxisGap,
            ),
          ),
        ],
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
        AppLocalizations.of(context).translate("no_calories_range"),
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
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

  int _todayCalories() {
    final now = DateTime.now();
    final key = DateTime(now.year, now.month, now.day);
    return _daily[key] ?? 0;
  }

  Future<void> _promptManualEntry() async {
    if (!_canManualEdit) return;
    final controller = TextEditingController(
      text: _todayCalories() > 0 ? _todayCalories().toString() : '',
    );
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            "Edit today's calories",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "e.g. 520",
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
      await CaloriesService().clearManualTotalDisplayEntry(day);
      if (mounted) {
        _loadRange();
      }
      return;
    }

    if (result is int) {
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
