import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/account_storage.dart';
import '../services/diet/calories_service.dart';
import '../services/diet/diet_service.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';

class CaloriesDetailPage extends StatefulWidget {
  const CaloriesDetailPage({super.key});

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

  static const _caloriesGoalKey = "dashboard_calories_goal";

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
      _goal = sp.getInt(_caloriesGoalKey) ?? 500;
    });
  }

  Future<void> _editGoal() async {
    final controller = TextEditingController(text: (_goal ?? 500).toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text("Calories burn goal", style: TextStyle(color: Colors.white)),
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
      final now = DateTime.now();
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
      final data =
          await CaloriesService().fetchDailyCalories(start: start, end: now);
      if (!mounted) return;
      setState(() {
        _daily = data;
        _selectedBarIndex = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
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
                  child: Text(t("calories_edit_today")),
                ),
                const SizedBox(width: 10),
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
                    t("calories_goal_btn").replaceAll("{value}", (_goal ?? 500).toString()),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: (_selectedBarIndex == null ||
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
                            color: const Color(0xFF35B6FF).withValues(alpha: 0.45),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barAreaHeight = constraints.maxHeight;
          final barAreaWidth =
              (constraints.maxWidth - yAxisWidth - yAxisGap).clamp(0.0, double.infinity);
          final barSlot = isDense
              ? (barAreaWidth / (entries.isEmpty ? 1 : entries.length))
              : null;
          final barWidth = isDense
              ? (barSlot! - (barSpacing * 2)).clamp(0.0, double.infinity)
              : null;

          final bars = entries.asMap().entries.map((pair) {
            final index = pair.key;
            final e = pair.value;
            final isSelected = _selectedBarIndex == index;
            final heightFactor = (e.value / safeMax).clamp(0.0, 1.0);
            final bar = Container(
              height: barAreaHeight * heightFactor,
              width: barWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1.1,
                      )
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isSelected
                      ? const [
                          Color(0xFFFFC266),
                          Color(0xFFFFE1A6),
                        ]
                      : const [
                          Color(0xFFFF8A00),
                          Color(0xFFFFC266),
                        ],
                ),
              ),
            );

            final content = Align(
              alignment: Alignment.bottomCenter,
              child: bar,
            );

            if (isDense) {
              return SizedBox(
                width: barSlot,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: barSpacing),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onBarTap(index),
                    child: content,
                  ),
                ),
              );
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: barSpacing),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onBarTap(index),
                  child: content,
                ),
              ),
            );
          }).toList();

          final yAxisHeight = constraints.maxHeight;
          double _yForValue(num v) {
            final ratio = (v / safeMax).clamp(0.0, 1.0);
            return (1.0 - ratio) * yAxisHeight;
          }

          final yAxis = SizedBox(
            width: yAxisWidth,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: Text(
                    _fmtCalories(safeMax),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: (_yForValue(avgVal) - 6).clamp(0.0, yAxisHeight - 12),
                  child: Text(
                    _fmtCalories(avgVal),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text(
                    "0",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );

          final gridLineColor = Colors.white.withValues(alpha: 0.06);
          final barArea = SizedBox(
            height: barAreaHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: barAreaHeight,
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
                  children: bars,
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

  List<_CaloriesBarEntry> _prepareEntries() {
    if (_daily.isEmpty) return [];
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

    final Map<String, List<int>> buckets = {};
    _daily.forEach((day, calories) {
      final label = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      buckets.putIfAbsent(label, () => []).add(calories);
    });

    final entries = buckets.entries
        .map<_CaloriesBarEntry>((e) {
          final avg = e.value.isEmpty
              ? 0
              : e.value.reduce((a, b) => a + b) ~/ e.value.length;
          return _CaloriesBarEntry(
            axisLabel: "",
            detailLabel: e.key,
            value: avg,
          );
        })
        .toList()
      ..sort((a, b) => a.detailLabel.compareTo(b.detailLabel));

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
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
        return t("range_last30");
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
    final controller = TextEditingController(
      text: _todayCalories() > 0 ? _todayCalories().toString() : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text("Edit today's calories", style: TextStyle(color: Colors.white)),
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
      await CaloriesService().saveManualEntry(day, result);
      // Submit burn so surplus rule runs (e.g. when user lowers value, targets go down).
      final userId = await AccountStorage.getUserId();
      if (userId != null) {
        try {
          await DailyMetricsApi.submitBurn(
            userId: userId,
            caloriesBurned: result,
            entryDate: day,
          );
          if (day.year == today.year && day.month == today.month && day.day == today.day) {
            await DietService.fetchCurrentTargets(userId);
            DietService.notifyTargetsUpdatedAfterBurn();
          }
        } catch (_) {
          // Ignore; next dashboard load or sync will submit.
        }
      }
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
