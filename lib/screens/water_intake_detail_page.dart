import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
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
      title: AppLocalizations.of(context).translate("common_edit_goal_title"),
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
      title: AppLocalizations.of(context).translate("water_add_dialog_title"),
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: TaqaPageAppBar(
        title: t("water_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      ),
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
                    "${t("water_goal_btn").replaceAll("{value}", (_goal ?? 2.5).toStringAsFixed(1))} ${t("dash_unit_l")}",
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t("common_history"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 11 / 10,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _buildHistoryLogs(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryLogs(String Function(String) t) {
    final logs = _daily.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final nonZero = logs.where((e) => e.value > 0).toList();

    if (nonZero.isEmpty) {
      return TaqaEmptyCard(
        title: t("dash_no_water_data"),
        subtitle: t("common_no_records_in_range"),
        icon: Icons.water_drop_outlined,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          itemCount: nonZero.length,
          separatorBuilder: (_, _) => SizedBox(height: TaqaUiScale.h(10)),
          itemBuilder: (context, index) {
            final entry = nonZero[index];
            return Container(
              padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiScale.radius(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${entry.value.toStringAsFixed(1)} ${t("dash_unit_l")}",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 25 / 15,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(19)),
                  Text(
                    "${_weekdayShort(entry.key.weekday)}, ${entry.key.day} ${_monthShort(entry.key.month)} ${entry.key.year}",
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17,
                      letterSpacing: 0,
                      height: 21 / 15,
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
