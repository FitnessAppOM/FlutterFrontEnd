import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/health/water_service.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../theme/app_theme.dart';

class WaterIntakeDetailPage extends StatefulWidget {
  const WaterIntakeDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<WaterIntakeDetailPage> createState() => _WaterIntakeDetailPageState();
}

class _WaterIntakeDetailPageState extends State<WaterIntakeDetailPage> {
  String _range = 'weekly';
  bool _loading = true;
  Map<DateTime, double> _daily = {};
  double? _goal;
  late final DateTime _anchorDate;

  static const _waterGoalKey = "water_goal_liters";

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

  Future<void> _loadGoal() async {
    final sp = await SharedPreferences.getInstance();
    final userId = await AccountStorage.getUserId();
    final key = userId == null ? _waterGoalKey : "${_waterGoalKey}_u$userId";
    setState(() {
      _goal = sp.getDouble(key) ?? 2.5;
    });
  }

  Future<void> _editGoal() async {
    if (!_canManualEdit) return;
    final text = await showTaqaTextValueDialog(
      context: context,
      title: "Edit goal",
      initialValue: (_goal ?? 2.5).toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final parsed = text == null ? null : double.tryParse(text.trim());
    if (parsed == null || parsed <= 0) return;
    await WaterService().setGoal(parsed);
    if (!mounted) return;
    setState(() => _goal = parsed);
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
          _loading = false;
        });
        return;
      }

      final fetched = await DailyMetricsApi.fetchRange(
        userId: userId,
        start: start,
        end: effectiveEnd,
      );

      final data = <DateTime, double>{};
      fetched.forEach((day, entry) {
        final key = DateTime(day.year, day.month, day.day);
        final liters = entry.waterLiters ?? 0;
        if (liters > 0) {
          data[key] = liters;
        }
      });

      final waterService = WaterService();
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(
        effectiveEnd.year,
        effectiveEnd.month,
        effectiveEnd.day,
      );
      while (!cursor.isAfter(last)) {
        final local = await waterService.getIntakeForDay(cursor);
        if (local > 0) {
          data[DateTime(cursor.year, cursor.month, cursor.day)] = local;
        }
        cursor = cursor.add(const Duration(days: 1));
      }

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

  void _onRangeTabTap(String value) {
    if (_range == value) return;
    setState(() => _range = value);
    _loadRange();
  }

  Future<void> _promptManualEntry() async {
    if (!_canManualEdit) return;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final current = await WaterService().getIntakeForDay(day);
    if (!mounted) return;
    final text = await showTaqaTextValueDialog(
      context: context,
      title: "Add water (L)",
      initialValue: current > 0 ? current.toStringAsFixed(1) : '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final parsed = text == null ? null : double.tryParse(text.trim());
    if (parsed == null || parsed < 0) return;
    await WaterService().setIntakeForDay(day, parsed);
    final userId = await AccountStorage.getUserId();
    if (userId != null) {
      try {
        await DailyMetricsApi.upsert(
          userId: userId,
          entryDate: day,
          waterLiters: parsed,
        );
        DailyMetricsApi.clearCache();
      } catch (_) {}
    }
    if (mounted) {
      _loadRange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("water_title"),
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
                    "Goal: ${(_goal ?? 2.5).toStringAsFixed(1)} ${t("dash_unit_l")}",
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "History",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _buildHistoryLogs(theme, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryLogs(ThemeData theme, String Function(String) t) {
    final logs = _daily.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final nonZero = logs.where((e) => e.value > 0).toList();

    if (nonZero.isEmpty) {
      return _noDataCard(theme);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          itemCount: nonZero.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = nonZero[index];
            return Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${entry.value.toStringAsFixed(1)} ${t("dash_unit_l")}",
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 2.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${_weekdayShort(entry.key.weekday)}, ${entry.key.day} ${_monthShort(entry.key.month)} ${entry.key.year}",
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 2.1,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
        "No water data for this range.",
        style: theme.textTheme.bodyMedium?.copyWith(
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
        textAlign: TextAlign.center,
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

class predefined3 {}
