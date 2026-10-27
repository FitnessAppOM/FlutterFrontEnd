import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_popup_guard.dart';
import '../../TaqaUI/components/taqa_timeline.dart';
import '../../TaqaUI/components/taqa_time_input_dialog.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/day_timeline_service.dart';
import '../../services/training/training_schedule_service.dart';
import '../../widgets/diet_item_search_sheet.dart';
import '../../widgets/diet_manual_entry_sheet.dart';
import '../../widgets/diet_photo_entry_sheet.dart';
import 'calendar_meal_editor_sheet.dart';
import 'training_plan_picker_sheet.dart';

class DayTimelinePage extends StatefulWidget {
  const DayTimelinePage({
    super.key,
    required this.date,
    required this.program,
    this.canEditTrainingPlan = false,
  });

  final DateTime date;
  final Map<String, dynamic> program;
  final bool canEditTrainingPlan;

  @override
  State<DayTimelinePage> createState() => _DayTimelinePageState();
}

class _DayTimelinePageState extends State<DayTimelinePage> {
  DayTimelineData? _data;
  Timer? _dueMealRefreshTimer;
  bool _loading = true;
  bool _savingMeal = false;
  bool _savingActivity = false;
  final Set<int> _completingPlanIds = <int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId <= 0) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).translate('error_generic');
      });
      return;
    }
    try {
      final data = await DayTimelineService.fetch(
        userId: userId,
        date: widget.date,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _scheduleDueMealRefresh(data);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(
          context,
        ).translate('day_timeline_load_error');
      });
    }
  }

  void _scheduleDueMealRefresh(DayTimelineData data) {
    _dueMealRefreshTimer?.cancel();
    final now = DateTime.now();
    final futurePlanTimes =
        data.events
            .where((event) => event.type == 'planned_meal')
            .map((event) => event.occurredAt)
            .whereType<DateTime>()
            .where((time) => time.isAfter(now))
            .toList()
          ..sort();
    if (futurePlanTimes.isEmpty) return;
    _dueMealRefreshTimer = Timer(
      futurePlanTimes.first.difference(now) + const Duration(seconds: 1),
      _load,
    );
  }

  @override
  void dispose() {
    _dueMealRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _addMeal({int? initialHour}) async {
    if (_savingMeal) return;
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(widget.date, now);
    final initial = initialHour == null
        ? (isToday
              ? TimeOfDay.fromDateTime(now)
              : const TimeOfDay(hour: 12, minute: 0))
        : TimeOfDay(hour: initialHour, minute: 0);
    final t = AppLocalizations.of(context);
    final selectedTime = await showTaqaTimeInputDialog(
      context: context,
      initialTime: initial,
      title: t.translate('day_timeline_set_meal_time'),
      hourLabel: t.translate('day_timeline_hour'),
      minuteLabel: t.translate('day_timeline_minute'),
      invalidTimeMessage: t.translate('day_timeline_invalid_time'),
      cancelLabel: t.translate('common_cancel'),
      saveLabel: t.translate('common_save'),
    );
    if (!mounted || selectedTime == null) return;

    final scheduledAt = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId <= 0) return;
    final mode = await showTaqaOptionDialog<_CalendarMealEntryMode>(
      context: context,
      title: t.translate('diet_add_item_title'),
      cancelLabel: t.translate('common_cancel'),
      options: [
        TaqaDialogOption(
          value: _CalendarMealEntryMode.search,
          title: t.translate('diet_option_search'),
          subtitle: t.translate('diet_option_search_desc'),
        ),
        TaqaDialogOption(
          value: _CalendarMealEntryMode.manual,
          title: t.translate('diet_option_manual'),
          subtitle: t.translate('diet_option_manual_desc'),
        ),
        TaqaDialogOption(
          value: _CalendarMealEntryMode.photo,
          title: t.translate('diet_option_photo'),
          subtitle: t.translate('diet_option_photo_desc'),
        ),
      ],
    );
    if (!mounted || mode == null) return;
    switch (mode) {
      case _CalendarMealEntryMode.search:
        await _addMealFromSearch(userId, scheduledAt);
      case _CalendarMealEntryMode.manual:
        await _addMealManually(userId, scheduledAt);
      case _CalendarMealEntryMode.photo:
        await _addMealFromPhoto(userId, scheduledAt);
    }
  }

  Future<void> _addMealManually(int userId, DateTime scheduledAt) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    final entryKey = DayTimelineService.newEntryKey(userId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (_) => DietManualEntrySheet(
        rootContext: context,
        userId: userId,
        mealId: 0,
        mealTitle: t.translate('day_timeline_meal_default_name'),
        mealDate: widget.date,
        onSubmit: ({required mealName, required ingredients}) async {
          if (mounted) setState(() => _savingMeal = true);
          try {
            return await DayTimelineService.createMeal(
              userId: userId,
              scheduledAt: scheduledAt,
              title: mealName?.trim().isNotEmpty == true
                  ? mealName!.trim()
                  : t.translate('day_timeline_meal_default_name'),
              items: ingredients.map((item) {
                int number(String key) =>
                    (item[key] as num?)?.round() ??
                    double.tryParse(item[key]?.toString() ?? '')?.round() ??
                    0;
                return <String, dynamic>{
                  'name': item['ingredient_name']?.toString() ?? '',
                  'grams': item['grams'],
                  'calories': number('calories'),
                  'protein_g': number('protein_g'),
                  'carbs_g': number('carbs_g'),
                  'fat_g': number('fat_g'),
                  if (item['food_id'] != null) 'food_id': item['food_id'],
                };
              }).toList(),
              entryKey: entryKey,
            );
          } finally {
            if (mounted) setState(() => _savingMeal = false);
          }
        },
        successMessage: (response) => response['status'] == 'planned'
            ? t.translate('day_timeline_meal_planned')
            : t.translate('day_timeline_meal_logged'),
        onLogged: (_) async => _load(),
      ),
    );
  }

  Future<void> _addMealFromSearch(int userId, DateTime scheduledAt) async {
    if (!mounted || _savingMeal) return;
    final t = AppLocalizations.of(context);
    Map<String, dynamic>? picked;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (_) => DietItemSearchSheet(
        rootContext: context,
        userId: userId,
        mealId: 0,
        mealTitle: t.translate('day_timeline_meal_default_name'),
        onLogged: (_) async {},
        onPickForManualEntry: (ingredient) => picked = ingredient,
      ),
    );
    if (!mounted || picked == null) return;
    final item = picked!;
    int number(String key) =>
        (item[key] as num?)?.round() ??
        double.tryParse(item[key]?.toString() ?? '')?.round() ??
        0;
    await _saveMeal(
      userId: userId,
      scheduledAt: scheduledAt,
      title: item['name']?.toString().trim().isNotEmpty == true
          ? item['name'].toString().trim()
          : t.translate('day_timeline_meal_default_name'),
      items: [
        {
          'name': item['name']?.toString() ?? '',
          'grams': item['grams'],
          'calories': number('calories'),
          'protein_g': number('protein'),
          'carbs_g': number('carbs'),
          'fat_g': number('fat'),
          if (item['food_id'] != null) 'food_id': item['food_id'],
          'source': 'search',
        },
      ],
      entryKey: DayTimelineService.newEntryKey(userId),
    );
  }

  Future<void> _addMealFromPhoto(int userId, DateTime scheduledAt) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    final entryKey = DayTimelineService.newEntryKey(userId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(15)),
        ),
      ),
      builder: (_) => DietPhotoEntrySheet(
        rootContext: context,
        userId: userId,
        mealId: 0,
        mealTitle: t.translate('day_timeline_meal_default_name'),
        onSubmit:
            ({
              required photoBytes,
              required filename,
              required textDescription,
            }) async {
              if (mounted) setState(() => _savingMeal = true);
              try {
                return await DayTimelineService.createPhotoMeal(
                  userId: userId,
                  scheduledAt: scheduledAt,
                  photoBytes: photoBytes,
                  filename: filename,
                  textDescription: textDescription,
                  entryKey: entryKey,
                );
              } finally {
                if (mounted) setState(() => _savingMeal = false);
              }
            },
        successMessage: (response) => response['status'] == 'planned'
            ? t.translate('day_timeline_meal_planned')
            : t.translate('day_timeline_meal_logged'),
        onLogged: (_) async => _load(),
      ),
    );
  }

  Future<void> _saveMeal({
    required int userId,
    required DateTime scheduledAt,
    required String title,
    required List<Map<String, dynamic>> items,
    required String entryKey,
  }) async {
    if (_savingMeal) return;
    final t = AppLocalizations.of(context);
    setState(() => _savingMeal = true);
    try {
      final response = await DayTimelineService.createMeal(
        userId: userId,
        scheduledAt: scheduledAt,
        title: title,
        items: items,
        entryKey: entryKey,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        response['status'] == 'planned'
            ? t.translate('day_timeline_meal_planned')
            : t.translate('day_timeline_meal_logged'),
        type: AppToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _savingMeal = false);
    }
  }

  TrainingScheduleEntry? _selectedActivity() {
    final plan = _data?.plannedActivity;
    if (plan == null) return null;
    int? number(Object? value) =>
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    return TrainingScheduleEntry(
      scheduledDate: widget.date,
      scheduleType: plan['schedule_type']?.toString() ?? '',
      programId: number(plan['program_id']),
      trainingDayIndex: number(plan['training_day_index']),
      trainingDayLabel: plan['training_day_label']?.toString(),
      scheduledAt: DateTime.tryParse(
        plan['scheduled_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  Future<void> _addOrChangeActivity() async {
    if (_savingActivity || !widget.canEditTrainingPlan) return;
    final selection = await TaqaPopupGuard.bottomSheet<CalendarPlanSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingPlanPickerSheet(
        days: calendarProgramDays(widget.program),
        selected: _selectedActivity(),
      ),
    );
    if (!mounted || selection == null) return;
    DateTime? scheduledAt;
    if (!selection.isRest) {
      final existing = _selectedActivity()?.scheduledAt;
      final now = DateTime.now();
      final initial = existing != null
          ? TimeOfDay.fromDateTime(existing)
          : DateUtils.isSameDay(widget.date, now)
          ? TimeOfDay.fromDateTime(now)
          : const TimeOfDay(hour: 12, minute: 0);
      final t = AppLocalizations.of(context);
      final selectedTime = await showTaqaTimeInputDialog(
        context: context,
        initialTime: initial,
        title: t.translate('day_timeline_set_activity_time'),
        hourLabel: t.translate('day_timeline_hour'),
        minuteLabel: t.translate('day_timeline_minute'),
        invalidTimeMessage: t.translate('day_timeline_invalid_time'),
        cancelLabel: t.translate('common_cancel'),
        saveLabel: t.translate('common_save'),
      );
      if (!mounted || selectedTime == null) return;
      scheduledAt = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    }
    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId <= 0) return;
    setState(() => _savingActivity = true);
    try {
      await TrainingScheduleService.save(
        userId: userId,
        scheduledDate: widget.date,
        scheduleType: selection.isRest ? 'rest' : 'training',
        programId: selection.isRest ? null : calendarProgramId(widget.program),
        trainingDayIndex: selection.day?.dayIndex,
        scheduledAt: scheduledAt,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).translate('training_calendar_saved'),
        type: AppToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _savingActivity = false);
    }
  }

  Future<void> _removeActivity() async {
    if (_savingActivity || _data?.plannedActivity == null) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId <= 0) return;
    setState(() => _savingActivity = true);
    try {
      await TrainingScheduleService.remove(
        userId: userId,
        scheduledDate: widget.date,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).translate('training_calendar_removed'),
        type: AppToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _savingActivity = false);
    }
  }

  Future<void> _editActivity() async {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final action = await TaqaPopupGuard.bottomSheet<_ActivityEditAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: TaqaUiScale.insetsLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(TaqaUiScale.r(18)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaqaFilledButton(
                label: t.translate('training_calendar_change_plan'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_ActivityEditAction.change),
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              TaqaTextActionButton(
                label: t.translate('training_calendar_remove_plan'),
                icon: Icons.delete_outline,
                foregroundColor: colors.danger,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_ActivityEditAction.remove),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _ActivityEditAction.change:
        await _addOrChangeActivity();
      case _ActivityEditAction.remove:
        await _removeActivity();
      case null:
        return;
    }
  }

  Future<void> _editMeal(DayTimelineEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.taqaColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(18)),
        ),
      ),
      builder: (_) => CalendarMealEditorSheet(
        event: event,
        mealDate: widget.date,
        onChanged: _load,
      ),
    );
  }

  Future<void> _markMealEaten(DayTimelineEvent event) async {
    final planId = _asInt(event.details['plan_id']);
    if (planId <= 0 || _completingPlanIds.contains(planId)) return;
    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId <= 0) return;
    setState(() => _completingPlanIds.add(planId));
    try {
      await DayTimelineService.markMealPlanEaten(
        userId: userId,
        planId: planId,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).translate('day_timeline_meal_logged'),
        type: AppToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _completingPlanIds.remove(planId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: TaqaPageAppBar(title: t.translate('day_timeline_title')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    ),
                  ],
                )
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: TaqaUiScale.insetsLTRB(24, 80, 24, 24),
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colors.textSecondary,
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _load,
                      child: Text(t.translate('generating_retry')),
                    ),
                  ],
                )
              : _buildContent(context, _data!),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DayTimelineData data) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final eventsByHour = <int, List<Widget>>{};
    for (final event in data.events) {
      final time = event.occurredAt;
      if (time == null) continue;
      eventsByHour
          .putIfAbsent(time.hour, () => [])
          .add(
            _TimelineEventContent(
              event: event,
              completing: _completingPlanIds.contains(
                _asInt(event.details['plan_id']),
              ),
              onMarkEaten: event.type == 'planned_meal'
                  ? () => _markMealEaten(event)
                  : null,
              onEdit: event.type == 'meal' || event.type == 'planned_meal'
                  ? () => _editMeal(event)
                  : null,
            ),
          );
    }
    final plannedActivity = data.plannedActivity;
    final plannedActivityTime = DateTime.tryParse(
      plannedActivity?['scheduled_at']?.toString() ?? '',
    )?.toLocal();
    if (plannedActivity != null && plannedActivityTime != null) {
      final isRest = plannedActivity['schedule_type'] == 'rest';
      eventsByHour
          .putIfAbsent(plannedActivityTime.hour, () => [])
          .add(
            TaqaTimelineEventCard(
              icon: isRest ? Icons.hotel_outlined : Icons.fitness_center,
              color: isRest ? colors.textSecondary : colors.accent,
              title: isRest
                  ? t.translate('training_calendar_rest_day')
                  : plannedActivity['training_day_label']?.toString() ??
                        t.translate('training_workout'),
              subtitle:
                  '${DateFormat.jm(t.locale.languageCode).format(plannedActivityTime)} · '
                  '${t.translate('day_timeline_planned')}',
              details: Text(
                t.translate('training_calendar_planned'),
                style: TextStyle(color: colors.textSecondary),
              ),
              onEdit: _editActivity,
            ),
          );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: TaqaUiScale.insetsLTRB(20, 12, 20, 32),
      children: [
        Text(
          DateFormat.yMMMMEEEEd(t.locale.languageCode).format(widget.date),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: colors.textPrimary,
            fontSize: TaqaUiScale.sp(23),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(18)),
        _buildAllDaySummary(context, data),
        SizedBox(height: TaqaUiScale.h(24)),
        Text(
          t.translate('day_timeline_hourly'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: TaqaUiScale.sp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        TaqaFilledButton(
          label: t.translate('day_timeline_log_food'),
          onTap: _savingMeal ? null : _addMeal,
          loading: _savingMeal,
        ),
        if (widget.canEditTrainingPlan && data.plannedActivity == null) ...[
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: t.translate('day_timeline_add_activity'),
            onTap: _savingActivity ? null : _addOrChangeActivity,
            loading: _savingActivity,
          ),
        ],
        SizedBox(height: TaqaUiScale.h(4)),
        Text(
          data.events.isEmpty
              ? t.translate('day_timeline_no_events')
              : t.translate('day_timeline_tap_details'),
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: TaqaUiScale.sp(12),
          ),
        ),
        SizedBox(height: TaqaUiScale.h(12)),
        TaqaHourlyTimeline(
          hourLabel: (hour) => DateFormat.j(t.locale.languageCode).format(
            DateTime(
              widget.date.year,
              widget.date.month,
              widget.date.day,
              hour,
            ),
          ),
          eventsByHour: eventsByHour,
          onEmptyHourTap: (hour) => _addMeal(initialHour: hour),
        ),
      ],
    );
  }

  Widget _buildAllDaySummary(BuildContext context, DayTimelineData data) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final metrics = data.dailySummary;
    final plan = data.plannedActivity;
    final planTime = DateTime.tryParse(
      plan?['scheduled_at']?.toString() ?? '',
    )?.toLocal();
    final cards = <Widget>[];

    if (plan != null && planTime == null) {
      final isRest = plan['schedule_type'] == 'rest';
      cards.add(
        TaqaTimelineSummaryCard(
          icon: isRest ? Icons.hotel_outlined : Icons.event_available,
          color: isRest ? colors.textSecondary : colors.accent,
          title: t.translate('day_timeline_planned'),
          value: isRest
              ? t.translate('training_calendar_rest_day')
              : plan['training_day_label']?.toString() ??
                    t.translate('training_workout'),
          onEdit: widget.canEditTrainingPlan ? _editActivity : null,
        ),
      );
    }

    final sleepMinutes = _sleepMinutes(metrics);
    if (sleepMinutes > 0) {
      cards.add(
        TaqaTimelineSummaryCard(
          icon: Icons.bedtime_outlined,
          color: TaqaUiColors.calendarSleep,
          title: t.translate('training_calendar_sleep'),
          value: _durationLabel(context, sleepMinutes),
          detail: _sleepDetail(context, metrics!),
        ),
      );
    }

    if (_hasDailyActivity(metrics)) {
      final activityParts = <String>[];
      final steps = _asInt(metrics?['steps']);
      final activeMinutes = _asInt(metrics?['active_minutes']);
      if (steps > 0) {
        activityParts.add(
          '${NumberFormat.decimalPattern(t.locale.languageCode).format(steps)} ${t.translate('training_calendar_steps')}',
        );
      }
      if (activeMinutes > 0) {
        activityParts.add(
          '$activeMinutes ${t.translate('training_calendar_active_minutes')}',
        );
      }
      cards.add(
        TaqaTimelineSummaryCard(
          icon: Icons.directions_walk,
          color: TaqaUiColors.calendarActivity,
          title: t.translate('training_calendar_daily_activity'),
          value: activityParts.isEmpty
              ? t.translate('day_timeline_daily_totals')
              : activityParts.join(' · '),
          detail: _activityDetail(context, metrics!),
        ),
      );
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('day_timeline_all_day'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: TaqaUiScale.sp(16),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        ...cards.map(
          (card) => Padding(
            padding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
            child: card,
          ),
        ),
      ],
    );
  }

  int _sleepMinutes(Map<String, dynamic>? metrics) {
    if (metrics == null) return 0;
    final asleep = _asInt(metrics['sleep_minutes_asleep']);
    if (asleep > 0) return asleep;
    final hours = _asDouble(metrics['sleep_hours']);
    return hours > 0 ? (hours * 60).round() : 0;
  }

  bool _hasDailyActivity(Map<String, dynamic>? metrics) {
    if (metrics == null) return false;
    return _asInt(metrics['steps']) > 0 ||
        _asInt(metrics['active_minutes']) > 0 ||
        _asInt(metrics['workout_minutes']) > 0 ||
        _asInt(metrics['calories']) > 0 ||
        _asDouble(metrics['water_liters']) > 0;
  }

  String _sleepDetail(BuildContext context, Map<String, dynamic> metrics) {
    final t = AppLocalizations.of(context);
    final parts = <String>[];
    final deep = _asInt(metrics['sleep_minutes_deep']);
    final rem = _asInt(metrics['sleep_minutes_rem']);
    final light = _asInt(metrics['sleep_minutes_light']);
    if (deep > 0) {
      parts.add(
        '${t.translate('day_timeline_deep')} ${_durationLabel(context, deep)}',
      );
    }
    if (rem > 0) {
      parts.add(
        '${t.translate('day_timeline_rem')} ${_durationLabel(context, rem)}',
      );
    }
    if (light > 0) {
      parts.add(
        '${t.translate('day_timeline_light')} ${_durationLabel(context, light)}',
      );
    }
    return parts.join(' · ');
  }

  String _activityDetail(BuildContext context, Map<String, dynamic> metrics) {
    final t = AppLocalizations.of(context);
    final parts = <String>[];
    final workout = _asInt(metrics['workout_minutes']);
    final calories = _asInt(metrics['calories']);
    final water = _asDouble(metrics['water_liters']);
    final restingHr = _asInt(metrics['resting_hr']);
    final hrv = _asDouble(metrics['hrv_ms']);
    if (workout > 0) {
      parts.add('$workout ${t.translate('training_calendar_workout_minutes')}');
    }
    if (calories > 0) {
      parts.add('$calories ${t.translate('training_calendar_kcal_burned')}');
    }
    if (water > 0) {
      parts.add('${_trimNumber(water)} ${t.translate('day_timeline_liters')}');
    }
    if (restingHr > 0) {
      parts.add('$restingHr ${t.translate('day_timeline_resting_hr')}');
    }
    if (hrv > 0) {
      parts.add('${_trimNumber(hrv)} ${t.translate('day_timeline_hrv')}');
    }
    return parts.join(' · ');
  }
}

enum _CalendarMealEntryMode { search, manual, photo }

enum _ActivityEditAction { change, remove }

class _TimelineEventContent extends StatelessWidget {
  const _TimelineEventContent({
    required this.event,
    required this.completing,
    this.onMarkEaten,
    this.onEdit,
  });

  final DayTimelineEvent event;
  final bool completing;
  final VoidCallback? onMarkEaten;
  final VoidCallback? onEdit;

  Color _color() => switch (event.type) {
    'meal' || 'planned_meal' => TaqaUiColors.calendarMeal,
    'strength' => TaqaUiColors.calendarStrength,
    'cardio' => TaqaUiColors.calendarCardio,
    _ => TaqaUiColors.calendarActivity,
  };

  IconData _icon() => switch (event.type) {
    'meal' => Icons.restaurant_outlined,
    'planned_meal' => Icons.schedule,
    'strength' => Icons.fitness_center,
    'cardio' => Icons.directions_run,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return TaqaTimelineEventCard(
      icon: _icon(),
      color: color,
      title: event.title,
      subtitle: _subtitle(context),
      details: _details(context),
      onEdit: onEdit,
    );
  }

  String _subtitle(BuildContext context) {
    final t = AppLocalizations.of(context);
    final time = event.occurredAt == null
        ? ''
        : DateFormat.jm(t.locale.languageCode).format(event.occurredAt!);
    if (event.type == 'meal' || event.type == 'planned_meal') {
      final totals = _map(event.details['totals']);
      final status = event.type == 'planned_meal'
          ? '${t.translate('day_timeline_planned')} · '
          : '';
      return '$time · $status${_asInt(totals['calories'])} ${t.translate('training_calendar_kcal')} · '
          'P ${_asInt(totals['protein_g'])}g · C ${_asInt(totals['carbs_g'])}g · F ${_asInt(totals['fat_g'])}g';
    }
    if (event.type == 'strength') {
      final exercises = _listOfMaps(event.details['exercises']);
      final seconds = _asInt(event.details['duration_seconds']);
      final parts = <String>[
        time,
        '${exercises.length} ${t.translate('training_calendar_exercises')}',
      ];
      if (seconds > 0) {
        parts.add(_durationLabel(context, (seconds / 60).round()));
      }
      return parts.where((part) => part.isNotEmpty).join(' · ');
    }
    final seconds = _asInt(event.details['duration_seconds']);
    final distance = _asDouble(event.details['distance_km']);
    final parts = <String>[time];
    if (seconds > 0) parts.add(_durationLabel(context, (seconds / 60).round()));
    if (distance > 0) {
      parts.add('${_trimNumber(distance)} ${t.translate('day_timeline_km')}');
    }
    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  Widget _details(BuildContext context) {
    return switch (event.type) {
      'meal' => _mealDetails(context),
      'planned_meal' => _plannedMealDetails(context),
      'strength' => _strengthDetails(context),
      'cardio' => _cardioDetails(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _plannedMealDetails(BuildContext context) {
    final canMarkEaten = event.details['can_mark_eaten'] == true;
    return Column(
      children: [
        _mealDetails(context),
        if (canMarkEaten && onMarkEaten != null) ...[
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: AppLocalizations.of(
              context,
            ).translate('day_timeline_mark_eaten'),
            onTap: completing ? null : onMarkEaten,
            loading: completing,
          ),
        ] else ...[
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            AppLocalizations.of(
              context,
            ).translate('day_timeline_available_at_time'),
            style: TextStyle(
              color: context.taqaColors.textSecondary,
              fontSize: TaqaUiScale.sp(10),
            ),
          ),
        ],
      ],
    );
  }

  Widget _mealDetails(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final items = _listOfMaps(event.details['items']);
    if (items.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          t.translate('day_timeline_manual_totals'),
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }
    return Column(
      children: items.map((item) {
        return TaqaTimelineDetailLine(
          title: item['name']?.toString() ?? t.translate('day_timeline_food'),
          subtitle:
              '${_asInt(item['calories'])} ${t.translate('training_calendar_kcal')} · '
              'P ${_asInt(item['protein_g'])}g · C ${_asInt(item['carbs_g'])}g · F ${_asInt(item['fat_g'])}g',
        );
      }).toList(),
    );
  }

  Widget _strengthDetails(BuildContext context) {
    final t = AppLocalizations.of(context);
    final exercises = _listOfMaps(event.details['exercises']);
    return Column(
      children: exercises.map((exercise) {
        final sets = _listOfMaps(exercise['sets']);
        final fallback = <String>[];
        if (_asInt(exercise['performed_sets']) > 0) {
          fallback.add(
            '${_asInt(exercise['performed_sets'])} ${t.translate('day_timeline_sets')}',
          );
        }
        if (_asInt(exercise['performed_reps']) > 0) {
          fallback.add(
            '${_asInt(exercise['performed_reps'])} ${t.translate('day_timeline_reps')}',
          );
        }
        if (_asDouble(exercise['weight_kg']) > 0) {
          fallback.add('${_trimNumber(_asDouble(exercise['weight_kg']))} kg');
        }
        return Padding(
          padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaqaTimelineDetailLine(
                title:
                    exercise['name']?.toString() ??
                    t.translate('day_timeline_exercise'),
                subtitle: sets.isEmpty
                    ? fallback.join(' · ')
                    : '${sets.length} ${t.translate('day_timeline_sets')}',
              ),
              if (sets.isNotEmpty)
                ...sets.map(
                  (set) => Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: TaqaUiScale.w(10),
                      top: TaqaUiScale.h(3),
                    ),
                    child: Text(
                      _setLabel(context, set),
                      style: TextStyle(
                        color: context.taqaColors.textSecondary,
                        fontSize: TaqaUiScale.sp(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _setLabel(BuildContext context, Map<String, dynamic> set) {
    final t = AppLocalizations.of(context);
    final parts = <String>[
      '${t.translate('day_timeline_set')} ${_asInt(set['set_index'])}',
    ];
    if (_asInt(set['reps']) > 0) {
      parts.add('${_asInt(set['reps'])} ${t.translate('day_timeline_reps')}');
    }
    if (_asDouble(set['weight_kg']) > 0) {
      parts.add('${_trimNumber(_asDouble(set['weight_kg']))} kg');
    }
    if (set['rir'] != null) parts.add('RIR ${_asInt(set['rir'])}');
    return parts.join(' · ');
  }

  Widget _cardioDetails(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = <Widget>[];
    void add(String label, String value) {
      rows.add(TaqaTimelineDetailLine(title: label, subtitle: value));
    }

    final distance = _asDouble(event.details['distance_km']);
    final pace = _asDouble(event.details['avg_pace_min_km']);
    final steps = _asInt(event.details['steps']);
    final incline = _asDouble(event.details['incline_percent']);
    if (distance > 0) {
      add(t.translate('day_timeline_distance'), '${_trimNumber(distance)} km');
    }
    if (pace > 0) {
      add(
        t.translate('day_timeline_pace'),
        '${_trimNumber(pace)} ${t.translate('day_timeline_min_per_km')}',
      );
    }
    if (steps > 0) {
      add(t.translate('training_calendar_steps'), '$steps');
    }
    if (incline > 0) {
      add(t.translate('day_timeline_incline'), '${_trimNumber(incline)}%');
    }
    return Column(children: rows);
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _listOfMaps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _asDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

String _trimNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _durationLabel(BuildContext context, int totalMinutes) {
  final t = AppLocalizations.of(context);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '$minutes${t.translate('training_calendar_minutes_short')}';
  }
  return '$hours${t.translate('training_calendar_hours_short')} '
      '$minutes${t.translate('training_calendar_minutes_short')}';
}
