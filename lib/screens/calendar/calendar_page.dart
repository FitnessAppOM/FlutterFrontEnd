import 'dart:async';

import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/components/taqa_calendar_ui.dart';
import '../../TaqaUI/components/taqa_calendar_icon.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_activity_types.dart';
import '../../services/diet/diet_calendar_service.dart';
import '../../services/calendar/calendar_source_loader.dart';
import '../../services/calendar/calendar_health_api.dart';
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
  Map<DateTime, Map<String, dynamic>> _healthDays = const {};
  Map<String, dynamic>? _selectedHealth;
  int _healthSelectionRequest = 0;
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;
  int? _pageUser;

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
    AccountStorage.accountChange.addListener(_loadMonth);
    unawaited(_loadMonth());
  }

  @override
  void dispose() {
    AccountStorage.accountChange.removeListener(_loadMonth);
    super.dispose();
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
        _selectedHealth = null;
        _healthSelectionRequest++;
      });
    }
    final userId = await AccountStorage.getUserId();
    if (!mounted || request != _loadRequest) return;
    if (_pageUser != null && userId != _pageUser) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(
          context,
        ).translate('calendar_time_account_changed');
      });
      return;
    }
    _pageUser = userId;
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
        CalendarSourceLoader.load<Map<String, dynamic>?>(
          source: 'manual_sessions',
          request: () => CalendarHealthApi.range(userId, start, end),
          fallback: null,
          onFailure: _reportSourceFailure,
        ),
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
        _healthDays = {
          for (final row in (results[5]?['days'] as List? ?? []))
            _day(DateTime.parse(row['entry_date'] as String)):
                Map<String, dynamic>.from(row as Map),
        };
        _loading = false;
      });
      unawaited(_loadSelectedHealth());
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

  void _changeMonth(int delta, {DateTime? selected}) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    setState(() {
      _visibleMonth = next;
      _selectedDate = selected ?? DateTime(next.year, next.month, 1);
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
    if (monthChanged) {
      unawaited(_loadMonth());
    } else {
      unawaited(_loadSelectedHealth());
    }
  }

  Future<void> _loadSelectedHealth() async {
    final request = ++_healthSelectionRequest;
    final day = _selectedDate;
    if (mounted) setState(() => _selectedHealth = null);
    final user = await AccountStorage.getUserId();
    if (user == null || user != _pageUser) return;
    try {
      final data = await CalendarHealthApi.day(user, day);
      if (mounted &&
          request == _healthSelectionRequest &&
          day == _selectedDate &&
          !_loading &&
          user == await AccountStorage.getUserId()) {
        setState(() => _selectedHealth = data);
      }
    } catch (_) {
      /* Optional source; the existing aggregate remains visible. */
    }
  }

  Future<void> _openDayTimeline(DateTime date) async {
    setState(() => _selectedDate = date);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DayTimelinePage(
          date: date,
          program: widget.program,
          canEditTrainingPlan: _programId != null && _programDays.isNotEmpty,
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
          style: calendarActionStyle(context),
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
              _buildCalendar(context),
              SizedBox(height: TaqaUiScale.h(14)),
              _buildLegend(context),
              SizedBox(height: TaqaUiScale.h(18)),
              _buildSelectedDay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final t = AppLocalizations.of(context);
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
    final days = List<TaqaCalendarDayData>.generate(
      cellCount,
      (index) => _calendarDayData(context, addCalendarDays(gridStart, index)),
    );

    return TaqaCalendarMonthCard(
      monthLabel: DateFormat.yMMMM(t.locale.languageCode).format(_visibleMonth),
      weekdayLabels: weekdayLabels,
      days: days,
      loading: _loading,
      error: _error,
      retryLabel: t.translate('generating_retry'),
      previousMonthTooltip: t.translate('training_calendar_previous_month'),
      nextMonthTooltip: t.translate('training_calendar_next_month'),
      onPreviousMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
      onRetry: _loadMonth,
      onDayTap: _selectCalendarDate,
    );
  }

  TaqaCalendarDayData _calendarDayData(BuildContext context, DateTime rawDate) {
    final t = AppLocalizations.of(context);
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
    final hasSleep =
        _sleepMinutes(metrics) > 0 ||
        ((_healthDays[date]?['sleep_count'] as num?) ?? 0) > 0;
    final hasDailyActivity =
        _hasDailyActivity(metrics) ||
        ((_healthDays[date]?['activity_count'] as num?) ?? 0) > 0;

    return TaqaCalendarDayData(
      date: date,
      inVisibleMonth: inMonth,
      selected: selected,
      today: isToday,
      semanticsLabel: [
        DateFormat.yMMMMEEEEd(t.locale.languageCode).format(date),
        if (isToday) t.translate('training_calendar_today'),
        if (hasStrength) t.translate('training_workout'),
        if (hasCardio) t.translate('training_calendar_cardio'),
        if (entry != null) t.translate('training_calendar_planned'),
        if (hasMeals || hasPlannedMeals) t.translate('training_calendar_meals'),
        if (hasSleep) t.translate('training_calendar_sleep'),
        if (hasDailyActivity) t.translate('training_calendar_daily_activity'),
      ].join(', '),
      indicatorColors: [
        if (hasStrength) TaqaUiColors.calendarStrength,
        if (hasCardio) TaqaUiColors.calendarCardio,
        if (!hasStrength && entry?.isTraining == true) colors.accent,
        if (entry?.isRest == true) colors.textSecondary,
        if (hasMeals || hasPlannedMeals) TaqaUiColors.calendarMeal,
        if (hasSleep) TaqaUiColors.calendarSleep,
        if (hasDailyActivity) TaqaUiColors.calendarActivity,
      ],
    );
  }

  void _selectCalendarDate(DateTime rawDate) {
    final date = _day(rawDate);
    final inMonth = date.month == _visibleMonth.month;
    if (!inMonth) {
      _changeMonth(
        date.isBefore(DateTime(_visibleMonth.year, _visibleMonth.month))
            ? -1
            : 1,
        selected: date,
      );
      return;
    }
    setState(() => _selectedDate = date);
    unawaited(_loadSelectedHealth());
  }

  Widget _buildLegend(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return TaqaCalendarLegend(
      items: [
        TaqaCalendarLegendItem(
          color: TaqaUiColors.calendarStrength,
          label: t.translate('training_completed'),
        ),
        TaqaCalendarLegendItem(
          color: TaqaUiColors.calendarCardio,
          label: t.translate('training_calendar_cardio'),
        ),
        TaqaCalendarLegendItem(
          color: colors.accent,
          label: t.translate('training_calendar_planned'),
        ),
        TaqaCalendarLegendItem(
          color: colors.textSecondary,
          label: t.translate('training_calendar_rest_day'),
        ),
        TaqaCalendarLegendItem(
          color: TaqaUiColors.calendarMeal,
          label: t.translate('training_calendar_meals'),
        ),
        TaqaCalendarLegendItem(
          color: TaqaUiColors.calendarSleep,
          label: t.translate('training_calendar_sleep'),
        ),
        TaqaCalendarLegendItem(
          color: TaqaUiColors.calendarActivity,
          label: t.translate('training_calendar_daily_activity'),
        ),
      ],
    );
  }

  Widget _buildSelectedDay(BuildContext context) {
    if (_loading || _error != null) return const SizedBox.shrink();
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
    final items = <TaqaCalendarSummaryItem>[];
    final activityCount =
        (_healthDays[_selectedDate]?['activity_count'] as num?) ?? 0;
    final sessions = _selectedHealth?['sessions'] as List?;
    if (sessions != null) {
      for (final session in sessions.where((s) => s['kind'] == 'activity')) {
        final activityKind = session['activity_kind'] as String;
        final totalMinutes = (session['duration_seconds'] as num).toInt() ~/ 60;
        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;
        final duration = hours == 0
            ? '$minutes${t.translate('training_calendar_minutes_short')}'
            : '$hours${t.translate('training_calendar_hours_short')} $minutes${t.translate('training_calendar_minutes_short')}';
        items.add(
          TaqaCalendarSummaryItem(
            icon: Icons.directions_walk,
            iconWidget: TaqaCalendarIcon(
              kind: 'activity',
              activityKind: activityKind,
              color: TaqaUiColors.calendarActivity,
            ),
            color: TaqaUiColors.calendarActivity,
            title: t.translate('calendar_health_$activityKind'),
            subtitle:
                '$duration${!calendarActivityHasDistance(activityKind) || session['distance_km'] == null ? '' : ' · ${session['distance_km']} ${t.translate('calendar_health_km')}'}',
          ),
        );
      }
    } else if (activityCount > 0) {
      items.add(
        TaqaCalendarSummaryItem(
          icon: Icons.directions_walk,
          color: TaqaUiColors.calendarActivity,
          title: t.translate('calendar_summary_activities'),
          subtitle: '$activityCount',
        ),
      );
    }
    for (final row in strength) {
      items.add(
        TaqaCalendarSummaryItem(
          icon: Icons.fitness_center,
          iconWidget: TaqaCalendarIcon(
            kind: 'training',
            color: TaqaUiColors.calendarStrength,
          ),
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
        TaqaCalendarSummaryItem(
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
        TaqaCalendarSummaryItem(
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
        TaqaCalendarSummaryItem(
          icon: Icons.restaurant_outlined,
          iconWidget: TaqaCalendarIcon(
            kind: 'food',
            color: TaqaUiColors.calendarMeal,
          ),
          color: TaqaUiColors.calendarMeal,
          title: t.translate('training_calendar_meals'),
          subtitle: mealParts.join(' · '),
        ),
      );
    }
    final selectedSleep = _selectedHealth?['sleep_summary'] as Map?;
    final sleepMinutes = selectedSleep == null
        ? _sleepMinutes(metrics)
        : (selectedSleep['minutes'] as num).round();
    if (sleepMinutes > 0) {
      final hours = sleepMinutes ~/ 60;
      final minutes = sleepMinutes % 60;
      items.add(
        TaqaCalendarSummaryItem(
          icon: Icons.bed_outlined,
          color: colors.textPrimary,
          title: t.translate('training_calendar_sleep'),
          subtitle:
              '$hours${t.translate('training_calendar_hours_short')} '
              '$minutes${t.translate('training_calendar_minutes_short')}'
              '${selectedSleep == null ? '' : '\n${t.translate('calendar_health_origin_${selectedSleep['origin']}')}'}',
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
        TaqaCalendarSummaryItem(
          icon: Icons.directions_walk,
          color: TaqaUiColors.calendarActivity,
          title: t.translate('training_calendar_daily_activity'),
          subtitle: details.join(' · '),
        ),
      );
    }

    return TaqaCalendarDaySummaryCard(
      dateLabel: DateFormat.yMMMMEEEEd(
        t.locale.languageCode,
      ).format(_selectedDate),
      items: items,
      emptyLabel: t.translate('training_calendar_no_activity'),
      actionLabel: isPast
          ? t.translate('calendar_modify_your_day')
          : t.translate('calendar_plan_your_day'),
      onAction: () => unawaited(_openDayTimeline(_selectedDate)),
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
