import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/diet/diet_calendar_service.dart';
import '../../services/calendar/calendar_source_loader.dart';
import '../../services/metrics/daily_metrics_api.dart';
import '../../services/training/training_schedule_service.dart';
import '../../services/training/training_service.dart';
import '../../utils/calendar_date_utils.dart';
import 'day_timeline_page.dart';
import 'training_plan_picker_sheet.dart';

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
  String? _error;
  int _loadRequest = 0;

  void _reportSourceFailure(
    String source,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('Calendar month source failed: $source ($error)');
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  void initState() {
    super.initState();
    final today = _day(DateTime.now());
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    unawaited(_loadMonth());
  }

  DateTime _day(DateTime value) => calendarDay(value);

  DateTime? _parseDay(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null ? null : _day(parsed);
  }

  List<CalendarProgramDay> get _programDays =>
      calendarProgramDays(widget.program);

  int? get _programId {
    return calendarProgramId(widget.program);
  }

  Future<List<Map<String, dynamic>>> _safeStrengthHistory(
    int userId,
    int limitDays,
  ) {
    return CalendarSourceLoader.load(
      source: 'strength_history',
      request: () => TrainingService.fetchTrainingHistory(
        userId: userId,
        limitDays: limitDays,
      ),
      fallback: const <Map<String, dynamic>>[],
      onFailure: _reportSourceFailure,
    );
  }

  Future<List<Map<String, dynamic>>> _safeCardioHistory(int userId) {
    return CalendarSourceLoader.load(
      source: 'cardio_history',
      request: () =>
          TrainingService.fetchCardioHistory(userId: userId, limit: 500),
      fallback: const <Map<String, dynamic>>[],
      onFailure: _reportSourceFailure,
    );
  }

  Future<List<TrainingScheduleEntry>> _safeTrainingSchedule(
    int userId,
    DateTime start,
    DateTime end,
  ) {
    return CalendarSourceLoader.load(
      source: 'training_schedule',
      request: () => TrainingScheduleService.fetchRange(
        userId: userId,
        start: start,
        end: end,
      ),
      fallback: const <TrainingScheduleEntry>[],
      onFailure: _reportSourceFailure,
    );
  }

  Future<Map<DateTime, DietCalendarDaySummary>> _safeMealSummaries(
    int userId,
    DateTime start,
    DateTime end,
  ) {
    return CalendarSourceLoader.load(
      source: 'meal_summaries',
      request: () => DietCalendarService.fetchRange(
        userId: userId,
        start: start,
        end: end,
      ),
      fallback: const <DateTime, DietCalendarDaySummary>{},
      onFailure: _reportSourceFailure,
    );
  }

  Future<Map<DateTime, DailyMetricsEntry>> _safeDailyMetrics(
    int userId,
    DateTime start,
    DateTime end,
  ) {
    return CalendarSourceLoader.load(
      source: 'daily_metrics',
      request: () =>
          DailyMetricsApi.fetchRange(userId: userId, start: start, end: end),
      fallback: const <DateTime, DailyMetricsEntry>{},
      onFailure: _reportSourceFailure,
    );
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
    final age = calendarDayDifference(today, start);
    final historyDays = age < 30 ? 30 : (age + 35).clamp(30, 2000);

    try {
      final results = await Future.wait<dynamic>([
        _safeTrainingSchedule(userId, start, end),
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DayTimelinePage(
          date: date,
          program: widget.program,
          canEditTrainingPlan: !(_strengthHistory[date]?.isNotEmpty ?? false),
        ),
      ),
    );
    if (!mounted) return;
    unawaited(_loadMonth());
  }

  CalendarProgramDay? _programDayFor(TrainingScheduleEntry? entry) {
    if (entry?.trainingDayIndex == null || entry?.programId != _programId) {
      return null;
    }
    for (final day in _programDays) {
      if (day.dayIndex == entry!.trainingDayIndex) return day;
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
    final gridStart = addCalendarDays(first, -offset);
    final weekdayLabels = List<String>.generate(7, (index) {
      final monday = addCalendarDays(DateTime(2024, 1, 1), index);
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
              final date = addCalendarDays(gridStart, index);
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
    final mealSummary = _mealSummaries[date];
    final hasMeals = mealSummary?.hasLoggedMeals ?? false;
    final hasPlannedMeals = mealSummary?.hasPlannedMeals ?? false;
    final metrics = _dailyMetrics[date];
    final hasSleep = _sleepMinutes(metrics) > 0;
    final hasDailyActivity = _hasDailyActivity(metrics);
    final dots = <Color>[
      if (hasStrength) TaqaUiColors.calendarStrength,
      if (hasCardio) TaqaUiColors.calendarCardio,
      if (!hasStrength && entry?.isTraining == true) colors.accent,
      if (entry?.isRest == true) colors.textSecondary,
      if (hasMeals) TaqaUiColors.calendarMeal,
      if (hasPlannedMeals && !hasMeals) TaqaUiColors.calendarMeal,
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
          subtitle: entry.scheduledAt == null
              ? t.translate('training_calendar_planned')
              : '${t.translate('training_calendar_planned')} · '
                    '${DateFormat.jm(t.locale.languageCode).format(entry.scheduledAt!)}',
        ),
      );
    }
    if (meals != null) {
      final mealParts = <String>[];
      if (meals.mealCount > 0) {
        mealParts.add(
          '${meals.mealCount} ${t.translate('training_calendar_meals_logged')} · '
          '${meals.itemCount} ${t.translate('training_calendar_food_items')} · '
          '${meals.calories} ${t.translate('training_calendar_kcal')}',
        );
      }
      if (meals.plannedMealCount > 0) {
        mealParts.add(
          '${meals.plannedMealCount} ${t.translate('day_timeline_meals_planned')}',
        );
      }
      items.add(
        _DaySummaryItem(
          icon: Icons.restaurant_outlined,
          color: TaqaUiColors.calendarMeal,
          title: t.translate('training_calendar_meals'),
          subtitle: mealParts.join(' · '),
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
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: isPast
                ? t.translate('calendar_modify_your_day')
                : t.translate('calendar_plan_your_day'),
            onTap: () => unawaited(_openDayTimeline(_selectedDate)),
          ),
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
