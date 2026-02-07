import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/diet/calories_service.dart';
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

  static const _caloriesGoalKey = "dashboard_calories_goal";

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadRange();
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
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daily = {};
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
    final safeMax = maxVal == 0 ? 1 : maxVal;
    const barWidth = 52.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: entries.map((e) {
            final heightFactor = (e.value / safeMax).clamp(0.0, 1.0);
            final label = e.key;
            return SizedBox(
              width: barWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 140 * heightFactor,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xFFFF8A00),
                                Color(0xFFFFC266),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.value.toStringAsFixed(0),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _prepareEntries() {
    if (_daily.isEmpty) return [];
    if (_range != 'yearly') {
      final entries = _daily.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return entries
          .map((e) => MapEntry("${e.key.month}/${e.key.day}", e.value))
          .toList();
    }

    final Map<String, List<int>> buckets = {};
    _daily.forEach((day, calories) {
      final label = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      buckets.putIfAbsent(label, () => []).add(calories);
    });

    final entries = buckets.entries.map<MapEntry<String, int>>((e) {
      final avg =
          e.value.isEmpty ? 0 : e.value.reduce((a, b) => a + b) ~/ e.value.length;
      return MapEntry(e.key, avg);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

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
      if (mounted) {
        _loadRange();
      }
    }
  }
}
