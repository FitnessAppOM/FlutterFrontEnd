import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/diet/diet_calendar_service.dart';
import '../../services/metrics/daily_metrics_api.dart';
import '../../services/training/training_schedule_service.dart';
import '../../services/training/training_service.dart';
import 'day_timeline_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.program});

  final Map<String, dynamic> program;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  Map<DateTime, TrainingScheduleEntry> _entries = const {};
  Map<DateTime, List<Map<String, dynamic>>> _strengthHistory = const {};
  Map<DateTime, List<Map<String, dynamic>>> _cardioHistory = const {};
  Map<DateTime, DietCalendarDaySummary> _mealSummaries = const {};
  Map<DateTime, DailyMetricsEntry> _dailyMetrics = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    final today = _day(DateTime.now());
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    unawaited(_loadMonth());
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime? _parseDay(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null ? null : _day(parsed);
  }

  List<_ProgramDay> get _programDays {
    final rawDays = widget.program['days'];
    if (rawDays is! List) return const [];
    final result = <_ProgramDay>[];
    for (var i = 0; i < rawDays.length; i++) {
      final raw = rawDays[i];
      if (raw is! Map) continue;
      final day = Map<String, dynamic>.from(raw);
      final rawId = day['day_id'] ?? day['day_index'];
      final id = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '') ?? i + 1;
      final rawLabel = day['day_label'] ?? day['label'];
      final label = rawLabel?.toString().trim();
      final exercises = day['exercises'];
      result.add(
        _ProgramDay(
          id: id > 0 ? id : i + 1,
          index: i,
          label: label == null || label.isEmpty ? 'Day ${i + 1}' : label,
          exerciseCount: exercises is List ? exercises.length : 0,
        ),
      );
    }
    return result;
  }

  int? get _programId {
    final raw = widget.program['program_id'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  Future<List<Map<String, dynamic>>> _safeStrengthHistory(
    int userId,
    int limitDays,
  ) async {
    try {
      return await TrainingService.fetchTrainingHistory(
        userId: userId,
        limitDays: limitDays,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeCardioHistory(int userId) async {
    try {
      return await TrainingService.fetchCardioHistory(
        userId: userId,
        limit: 500,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<Map<DateTime, DietCalendarDaySummary>> _safeMealSummaries(
    int userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await DietCalendarService.fetchRange(
        userId: userId,
        start: start,
        end: end,
      );
    } catch (_) {
      return const {};
    }
  }

  Future<Map<DateTime, DailyMetricsEntry>> _safeDailyMetrics(
    int userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await DailyMetricsApi.fetchRange(
        userId: userId,
        start: start,
        end: end,
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadMonth() async {
    final request = ++_loadRequest;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final userId = await AccountStorage.getUserId();
    if (!mounted || request != _loadRequest) return;
    if (userId == null || userId <= 0) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).translate('error_generic');
      });
      return;
    }

    final start = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final end = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final today = _day(DateTime.now());
    final age = today.difference(start).inDays;
    final historyDays = age < 30 ? 30 : (age + 35).clamp(30, 2000);

    try {
      final results = await Future.wait<dynamic>([
        TrainingScheduleService.fetchRange(
          userId: userId,
          start: start,
          end: end,
        ),
        _safeStrengthHistory(userId, historyDays),
        _safeCardioHistory(userId),
        _safeMealSummaries(userId, start, end),
        _safeDailyMetrics(userId, start, end),
      ]);
      if (!mounted || request != _loadRequest) return;

      final entries = <DateTime, TrainingScheduleEntry>{};
      for (final entry in results[0] as List<TrainingScheduleEntry>) {
        entries[_day(entry.scheduledDate)] = entry;
      }
      final strength = <DateTime, List<Map<String, dynamic>>>{};
      for (final row in results[1] as List<Map<String, dynamic>>) {
        final date = _parseDay(row['latest_date']);
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
        strength.putIfAbsent(date, () => []).add(row);
      }
      final cardio = <DateTime, List<Map<String, dynamic>>>{};
      for (final row in results[2] as List<Map<String, dynamic>>) {
        final date = _parseDay(row['entry_date']);
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
        cardio.putIfAbsent(date, () => []).add(row);
      }

      setState(() {
        _entries = entries;
        _strengthHistory = strength;
        _cardioHistory = cardio;
        _mealSummaries = results[3] as Map<DateTime, DietCalendarDaySummary>;
        _dailyMetrics = results[4] as Map<DateTime, DailyMetricsEntry>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(
          context,
        ).translate('training_calendar_load_error');
      });
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    setState(() {
      _visibleMonth = next;
      _selectedDate = DateTime(next.year, next.month, 1);
    });
    unawaited(_loadMonth());
  }

  void _goToToday() {
    final today = _day(DateTime.now());
    final monthChanged =
        today.year != _visibleMonth.year || today.month != _visibleMonth.month;
    setState(() {
      _visibleMonth = DateTime(today.year, today.month);
      _selectedDate = today;
    });
    if (monthChanged) unawaited(_loadMonth());
  }

  Future<void> _openDayTimeline(DateTime date) async {
    setState(() => _selectedDate = date);
    final today = _day(DateTime.now());
    final canEditPlan =
        !date.isBefore(today) && !(_strengthHistory[date]?.isNotEmpty ?? false);
    final editPlan = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            DayTimelinePage(date: date, canEditTrainingPlan: canEditPlan),
      ),
    );
    if (!mounted) return;
    if (editPlan == true) {
      await _showPlanPicker();
    } else {
      unawaited(_loadMonth());
    }
  }

  Future<void> _showPlanPicker() async {
    final t = AppLocalizations.of(context);
    final today = _day(DateTime.now());
    if (_selectedDate.isBefore(today) ||
        (_strengthHistory[_selectedDate]?.isNotEmpty ?? false)) {
      AppToast.show(
        context,
        t.translate('training_calendar_past_readonly'),
        type: AppToastType.info,
      );
      return;
    }

    final selection = await showModalBottomSheet<_PlanSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PlanPickerSheet(
        days: _programDays,
        selected: _entries[_selectedDate],
      ),
    );
    if (selection == null || !mounted) return;
    await _savePlan(selection);
  }

  Future<void> _savePlan(_PlanSelection selection) async {
    if (_saving) return;
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0 || !mounted) return;
    setState(() => _saving = true);
    try {
      await TrainingScheduleService.save(
        userId: userId,
        scheduledDate: _selectedDate,
        scheduleType: selection.isRest ? 'rest' : 'training',
        programId: selection.isRest ? null : _programId,
        trainingDayIndex: selection.day?.id,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate('training_calendar_saved'),
        type: AppToastType.success,
      );
      await _loadMonth();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate('error_generic'),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePlan() async {
    final entry = _entries[_selectedDate];
    if (_saving || entry == null) return;
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) return;
    setState(() => _saving = true);
    try {
      await TrainingScheduleService.remove(
        userId: userId,
        scheduledDate: _selectedDate,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate('training_calendar_removed'),
        type: AppToastType.success,
      );
      await _loadMonth();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate('error_generic'),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  _ProgramDay? _programDayFor(TrainingScheduleEntry? entry) {
    if (entry?.trainingDayIndex == null || entry?.programId != _programId) {
      return null;
    }
    for (final day in _programDays) {
      if (day.id == entry!.trainingDayIndex) return day;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: TaqaPageAppBar(
        title: t.translate('training_calendar'),
        trailing: TextButton(
          onPressed: _goToToday,
          child: Text(
            t.translate('training_calendar_today'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadMonth,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: TaqaUiScale.insetsLTRB(20, 12, 20, 28),
            children: [
              _buildMonthHeader(context),
              SizedBox(height: TaqaUiScale.h(12)),
              _buildCalendar(context),
              SizedBox(height: TaqaUiScale.h(18)),
              _buildLegend(context),
              SizedBox(height: TaqaUiScale.h(18)),
              _buildSelectedDay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Row(
      children: [
        IconButton(
          onPressed: _loading ? null : () => _changeMonth(-1),
          tooltip: t.translate('training_calendar_previous_month'),
          icon: const Icon(Icons.chevron_left),
          color: colors.textPrimary,
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM(t.locale.languageCode).format(_visibleMonth),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(21),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: _loading ? null : () => _changeMonth(1),
          tooltip: t.translate('training_calendar_next_month'),
          icon: const Icon(Icons.chevron_right),
          color: colors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    if (_loading) {
      return SizedBox(
        height: TaqaUiScale.h(310),
        child: Center(child: CircularProgressIndicator(color: colors.accent)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: TaqaUiScale.h(260),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadMonth,
                child: Text(t.translate('generating_retry')),
              ),
            ],
          ),
        ),
      );
    }

    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final offset = first.weekday - DateTime.monday;
    final cellCount = (((offset + daysInMonth) / 7).ceil() * 7);
    final gridStart = first.subtract(Duration(days: offset));
    final weekdayLabels = List<String>.generate(7, (index) {
      final monday = DateTime(2024, 1, 1).add(Duration(days: index));
      return DateFormat.E(t.locale.languageCode).format(monday);
    });

    return Container(
      padding: TaqaUiScale.insetsLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: TaqaUiScale.sp(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              return _buildDayCell(context, date);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime rawDate) {
    final colors = context.taqaColors;
    final date = _day(rawDate);
    final inMonth = date.month == _visibleMonth.month;
    final selected = date == _selectedDate;
    final isToday = date == _day(DateTime.now());
    final entry = _entries[date];
    final hasStrength = _strengthHistory[date]?.isNotEmpty ?? false;
    final hasCardio = _cardioHistory[date]?.isNotEmpty ?? false;
    final hasMeals = _mealSummaries.containsKey(date);
    final metrics = _dailyMetrics[date];
    final hasSleep = _sleepMinutes(metrics) > 0;
    final hasDailyActivity = _hasDailyActivity(metrics);
    final dots = <Color>[
      if (hasStrength) TaqaUiColors.calendarStrength,
      if (hasCardio) TaqaUiColors.calendarCardio,
      if (!hasStrength && entry?.isTraining == true) colors.accent,
      if (entry?.isRest == true) colors.textSecondary,
      if (hasMeals) TaqaUiColors.calendarMeal,
      if (hasSleep) TaqaUiColors.calendarSleep,
      if (hasDailyActivity) TaqaUiColors.calendarActivity,
    ];
    return InkWell(
      borderRadius: TaqaUiScale.radius(12),
      onTap: () {
        if (!inMonth) {
          final delta =
              date.isBefore(DateTime(_visibleMonth.year, _visibleMonth.month))
              ? -1
              : 1;
          _changeMonth(delta);
          return;
        }
        setState(() => _selectedDate = date);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? colors.accent : Colors.transparent,
          borderRadius: TaqaUiScale.radius(12),
          border: isToday && !selected
              ? Border.all(color: colors.accent, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected
                    ? colors.onAccent
                    : inMonth
                    ? colors.textPrimary
                    : colors.textSecondary.withValues(alpha: 0.38),
                fontSize: TaqaUiScale.sp(12),
                fontWeight: isToday || selected
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(4)),
            SizedBox(
              height: TaqaUiScale.h(5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dots
                    .take(6)
                    .map(
                      (color) => Container(
                        width: TaqaUiScale.w(3.5),
                        height: TaqaUiScale.w(3.5),
                        margin: const EdgeInsets.symmetric(horizontal: 0.7),
                        decoration: BoxDecoration(
                          color: selected ? colors.onAccent : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Wrap(
      spacing: TaqaUiScale.w(14),
      runSpacing: TaqaUiScale.h(8),
      children: [
        _LegendItem(
          color: TaqaUiColors.calendarStrength,
          label: t.translate('training_completed'),
        ),
        _LegendItem(
          color: TaqaUiColors.calendarCardio,
          label: t.translate('training_calendar_cardio'),
        ),
        _LegendItem(
          color: colors.accent,
          label: t.translate('training_calendar_planned'),
        ),
        _LegendItem(
          color: colors.textSecondary,
          label: t.translate('training_calendar_rest_day'),
        ),
        _LegendItem(
          color: TaqaUiColors.calendarMeal,
          label: t.translate('training_calendar_meals'),
        ),
        _LegendItem(
          color: TaqaUiColors.calendarSleep,
          label: t.translate('training_calendar_sleep'),
        ),
        _LegendItem(
          color: TaqaUiColors.calendarActivity,
          label: t.translate('training_calendar_daily_activity'),
        ),
      ],
    );
  }

  Widget _buildSelectedDay(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final entry = _entries[_selectedDate];
    final strength = _strengthHistory[_selectedDate] ?? const [];
    final cardio = _cardioHistory[_selectedDate] ?? const [];
    final meals = _mealSummaries[_selectedDate];
    final metrics = _dailyMetrics[_selectedDate];
    final programDay = _programDayFor(entry);
    final today = _day(DateTime.now());
    final isPast = _selectedDate.isBefore(today);
    final items = <_DaySummaryItem>[];
    for (final row in strength) {
      items.add(
        _DaySummaryItem(
          icon: Icons.fitness_center,
          color: TaqaUiColors.calendarStrength,
          title: row['label']?.toString() ?? t.translate('training_workout'),
          subtitle:
              '${row['completed_count'] ?? 0}/${row['total_count'] ?? 0} ${t.translate('training_calendar_exercises')}',
        ),
      );
    }
    for (final row in cardio) {
      final duration = row['duration_seconds'] is num
          ? (row['duration_seconds'] as num).toInt()
          : 0;
      items.add(
        _DaySummaryItem(
          icon: Icons.directions_run,
          color: TaqaUiColors.calendarCardio,
          title:
              row['exercise_name']?.toString() ??
              t.translate('training_calendar_cardio'),
          subtitle: duration > 0
              ? '${(duration / 60).round()} ${t.translate('training_calendar_minutes')}'
              : t.translate('training_completed'),
        ),
      );
    }
    if (strength.isEmpty && entry != null) {
      items.add(
        _DaySummaryItem(
          icon: entry.isRest ? Icons.hotel_outlined : Icons.event_available,
          color: entry.isRest ? colors.textSecondary : colors.accent,
          title: entry.isRest
              ? t.translate('training_calendar_rest_day')
              : entry.trainingDayLabel ??
                    programDay?.label ??
                    t.translate('training_workout'),
          subtitle: t.translate('training_calendar_planned'),
        ),
      );
    }
    if (meals != null) {
      items.add(
        _DaySummaryItem(
          icon: Icons.restaurant_outlined,
          color: TaqaUiColors.calendarMeal,
          title: t.translate('training_calendar_meals'),
          subtitle:
              '${meals.mealCount} ${t.translate('training_calendar_meals_logged')} · '
              '${meals.itemCount} ${t.translate('training_calendar_food_items')} · '
              '${meals.calories} ${t.translate('training_calendar_kcal')}',
        ),
      );
    }
    final sleepMinutes = _sleepMinutes(metrics);
    if (sleepMinutes > 0) {
      final hours = sleepMinutes ~/ 60;
      final minutes = sleepMinutes % 60;
      items.add(
        _DaySummaryItem(
          icon: Icons.bedtime_outlined,
          color: TaqaUiColors.calendarSleep,
          title: t.translate('training_calendar_sleep'),
          subtitle:
              '$hours${t.translate('training_calendar_hours_short')} '
              '$minutes${t.translate('training_calendar_minutes_short')}',
        ),
      );
    }
    if (_hasDailyActivity(metrics)) {
      final details = <String>[];
      if ((metrics?.steps ?? 0) > 0) {
        details.add(
          '${NumberFormat.decimalPattern(t.locale.languageCode).format(metrics!.steps)} '
          '${t.translate('training_calendar_steps')}',
        );
      }
      if ((metrics?.activeMinutes ?? 0) > 0) {
        details.add(
          '${metrics!.activeMinutes} ${t.translate('training_calendar_active_minutes')}',
        );
      }
      if ((metrics?.workoutMinutes ?? 0) > 0) {
        details.add(
          '${metrics!.workoutMinutes} ${t.translate('training_calendar_workout_minutes')}',
        );
      }
      if ((metrics?.calories ?? 0) > 0) {
        details.add(
          '${metrics!.calories} ${t.translate('training_calendar_kcal_burned')}',
        );
      }
      items.add(
        _DaySummaryItem(
          icon: Icons.directions_walk,
          color: TaqaUiColors.calendarActivity,
          title: t.translate('training_calendar_daily_activity'),
          subtitle: details.join(' · '),
        ),
      );
    }

    return Container(
      padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd(t.locale.languageCode).format(_selectedDate),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: TaqaUiScale.h(14)),
              child: Text(
                t.translate('training_calendar_no_activity'),
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            ...items.map((item) => _DaySummaryRow(item: item)),
          TaqaTextActionButton(
            label: t.translate('training_calendar_show_more'),
            onTap: () => unawaited(_openDayTimeline(_selectedDate)),
          ),
          if (!isPast && strength.isEmpty) ...[
            SizedBox(height: TaqaUiScale.h(10)),
            TaqaFilledButton(
              label: entry == null
                  ? t.translate('training_calendar_schedule')
                  : t.translate('training_calendar_change_plan'),
              onTap: _saving ? null : _showPlanPicker,
              loading: _saving,
            ),
          ],
          if (_selectedDate == today &&
              strength.isEmpty &&
              entry?.isTraining == true &&
              programDay != null) ...[
            SizedBox(height: TaqaUiScale.h(8)),
            TaqaTextActionButton(
              label: t.translate('training_calendar_open_workout'),
              onTap: () => Navigator.of(context).pop(programDay.index),
            ),
          ],
          if (!isPast && strength.isEmpty && entry != null) ...[
            SizedBox(height: TaqaUiScale.h(2)),
            TaqaTextActionButton(
              label: t.translate('training_calendar_remove_plan'),
              onTap: _saving ? null : _removePlan,
            ),
          ],
        ],
      ),
    );
  }

  int _sleepMinutes(DailyMetricsEntry? metrics) {
    if (metrics == null) return 0;
    final asleep = metrics.sleepMinutesAsleep;
    if (asleep != null && asleep > 0) return asleep;
    final hours = metrics.sleepHours;
    return hours != null && hours > 0 ? (hours * 60).round() : 0;
  }

  bool _hasDailyActivity(DailyMetricsEntry? metrics) {
    if (metrics == null) return false;
    return (metrics.steps ?? 0) > 0 ||
        (metrics.activeMinutes ?? 0) > 0 ||
        (metrics.workoutMinutes ?? 0) > 0 ||
        (metrics.calories ?? 0) > 0;
  }
}

class _ProgramDay {
  const _ProgramDay({
    required this.id,
    required this.index,
    required this.label,
    required this.exerciseCount,
  });

  final int id;
  final int index;
  final String label;
  final int exerciseCount;
}

class _PlanSelection {
  const _PlanSelection.rest() : isRest = true, day = null;
  const _PlanSelection.training(this.day) : isRest = false;

  final bool isRest;
  final _ProgramDay? day;
}

class _PlanPickerSheet extends StatelessWidget {
  const _PlanPickerSheet({required this.days, required this.selected});

  final List<_ProgramDay> days;
  final TrainingScheduleEntry? selected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('training_calendar_select_workout'),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TaqaUiScale.sp(20),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              _PlanOption(
                icon: Icons.hotel_outlined,
                title: t.translate('training_calendar_rest_day'),
                selected: selected?.isRest == true,
                onTap: () =>
                    Navigator.of(context).pop(const _PlanSelection.rest()),
              ),
              ...days.map(
                (day) => _PlanOption(
                  icon: Icons.fitness_center,
                  title: day.label,
                  subtitle:
                      '${day.exerciseCount} ${t.translate('training_calendar_exercises')}',
                  selected:
                      selected?.isTraining == true &&
                      selected?.trainingDayIndex == day.id,
                  onTap: () =>
                      Navigator.of(context).pop(_PlanSelection.training(day)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Padding(
      padding: EdgeInsets.only(top: TaqaUiScale.h(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(12),
        child: Container(
          padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.14)
                : colors.surfaceElevated,
            borderRadius: TaqaUiScale.radius(12),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textPrimary, size: 20),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: TaqaUiScale.sp(11),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _DaySummaryItem {
  const _DaySummaryItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _DaySummaryRow extends StatelessWidget {
  const _DaySummaryRow({required this.item});

  final _DaySummaryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
      child: Row(
        children: [
          Container(
            width: TaqaUiScale.w(38),
            height: TaqaUiScale.w(38),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: TaqaUiScale.radius(10),
            ),
            child: Icon(item.icon, color: item.color, size: 19),
          ),
          SizedBox(width: TaqaUiScale.w(11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: TaqaUiScale.sp(11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
