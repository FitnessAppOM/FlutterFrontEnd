import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_timeline.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/day_timeline_service.dart';

class DayTimelinePage extends StatefulWidget {
  const DayTimelinePage({
    super.key,
    required this.date,
    this.canEditTrainingPlan = false,
  });

  final DateTime date;
  final bool canEditTrainingPlan;

  @override
  State<DayTimelinePage> createState() => _DayTimelinePageState();
}

class _DayTimelinePageState extends State<DayTimelinePage> {
  DayTimelineData? _data;
  bool _loading = true;
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
          .add(_TimelineEventContent(event: event));
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
        if (widget.canEditTrainingPlan) ...[
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: data.plannedActivity == null
                ? t.translate('training_calendar_schedule')
                : t.translate('training_calendar_change_plan'),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
        SizedBox(height: TaqaUiScale.h(24)),
        Text(
          t.translate('day_timeline_hourly'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: TaqaUiScale.sp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
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
        ),
      ],
    );
  }

  Widget _buildAllDaySummary(BuildContext context, DayTimelineData data) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    final metrics = data.dailySummary;
    final plan = data.plannedActivity;
    final cards = <Widget>[];

    if (plan != null) {
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

class _TimelineEventContent extends StatelessWidget {
  const _TimelineEventContent({required this.event});

  final DayTimelineEvent event;

  Color _color() => switch (event.type) {
    'meal' => TaqaUiColors.calendarMeal,
    'strength' => TaqaUiColors.calendarStrength,
    'cardio' => TaqaUiColors.calendarCardio,
    _ => TaqaUiColors.calendarActivity,
  };

  IconData _icon() => switch (event.type) {
    'meal' => Icons.restaurant_outlined,
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
    );
  }

  String _subtitle(BuildContext context) {
    final t = AppLocalizations.of(context);
    final time = event.occurredAt == null
        ? ''
        : DateFormat.jm(t.locale.languageCode).format(event.occurredAt!);
    if (event.type == 'meal') {
      final totals = _map(event.details['totals']);
      return '$time · ${_asInt(totals['calories'])} ${t.translate('training_calendar_kcal')} · '
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
      'strength' => _strengthDetails(context),
      'cardio' => _cardioDetails(context),
      _ => const SizedBox.shrink(),
    };
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
