import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health/steps_service.dart';
import '../services/fitbit/fitbit_steps_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';

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

  static const _stepsGoalKey = "dashboard_steps_goal";

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadRange();
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
          title: const Text("Steps goal", style: TextStyle(color: Colors.white)),
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
      final today = DateTime(now.year, now.month, now.day);
      DateTime start;
      switch (_range) {
        case 'monthly':
          start = now.subtract(const Duration(days: 30));
          break;
        case 'yearly':
          start = now.subtract(const Duration(days: 365));
          break;
        case 'weekly':
        default:
          start = now.subtract(const Duration(days: 7));
          break;
      }
      final data = widget.useFitbit
          ? await FitbitStepsService().fetchDailySteps(start: start, end: now)
          : await StepsService().fetchDailySteps(start: start, end: now);
      if (!mounted) return;
      setState(() {
        _daily = data;
        _rangeStart = DateTime(start.year, start.month, start.day);
        _rangeEnd = today;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t("steps_goal_btn").replaceAll("{value}", (_goal ?? 10000).toString()),
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
        setState(() => _range = value);
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barMaxHeight = constraints.maxHeight - labelHeight - labelGap;
              final barAreaWidth =
                  (constraints.maxWidth - yAxisWidth - yAxisGap).clamp(0.0, double.infinity);
              final barSlot = useFixedSlots
                  ? (barAreaWidth / (entries.isEmpty ? 1 : entries.length))
                  : null;
              final barWidth = useFixedSlots
                  ? (barSlot! - (barSpacing * 2)).clamp(4.0, double.infinity)
                  : null;

              final barWidgets = entries.map((e) {
                final heightFactor = (e.value / actualMax).clamp(0.0, 1.0);
                final label = e.key;
                final showLabel = label.isNotEmpty;
                final bar = Container(
                  height: barMaxHeight * heightFactor,
                  width: barWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xFF35B6FF),
                        Color(0xFF9B8CFF),
                      ],
                    ),
                  ),
                );

                final content = Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    bar,
                    const SizedBox(height: labelGap),
                    SizedBox(
                      height: labelHeight,
                      child: showLabel
                          ? Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );

                if (useFixedSlots) {
                  return SizedBox(
                    width: barSlot,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: barSpacing),
                      child: content,
                    ),
                  );
                }

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: barSpacing),
                    child: content,
                  ),
                );
              }).toList();

              final yAxis = SizedBox(
                width: yAxisWidth,
                height: barMaxHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatStepsAxis(actualMax),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatStepsAxis(midVal),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatStepsAxis(0),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );

              final gridLineColor = Colors.white.withValues(alpha: 0.06);
              final barArea = SizedBox(
                height: constraints.maxHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: barMaxHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(height: 1, color: gridLineColor),
                          Container(height: 1, color: gridLineColor),
                          Container(height: 1, color: gridLineColor),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: barWidgets,
                    ),
                  ],
                ),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  yAxis,
                  const SizedBox(width: yAxisGap),
                  Expanded(child: barArea),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range != 'yearly') {
      final start = _rangeStart;
      final end = _rangeEnd;
      if (start == null || end == null) {
        final entries = _daily.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries.map((e) => MapEntry("", e.value)).toList();
      }
      final items = <MapEntry<String, int>>[];
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
          final showLabel =
              dayNum == 1 || dayNum == lastDay || dayNum % 7 == 0;
          label = showLabel ? dayNum.toString() : "";
        }
        items.add(MapEntry(label, _daily[key] ?? 0));
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

    final entries = <MapEntry<String, int>>[];
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(last)) {
      final key = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
      final values = buckets[key] ?? const <int>[];
      final avg =
          values.isEmpty ? 0 : values.reduce((a, b) => a + b) ~/ values.length;
      entries.add(MapEntry(_monthShort(cursor.month), avg));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return entries;
  }

  Widget _noDataCard(ThemeData theme) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
        return t("range_last30");
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
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text("Edit today's steps", style: TextStyle(color: Colors.white)),
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
