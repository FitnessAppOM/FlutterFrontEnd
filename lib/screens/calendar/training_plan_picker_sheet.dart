import 'package:flutter/material.dart';

import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_schedule_service.dart';

class CalendarProgramDay {
  const CalendarProgramDay({
    required this.dayIndex,
    required this.listIndex,
    required this.label,
    required this.exerciseCount,
  });

  final int dayIndex;
  final int listIndex;
  final String label;
  final int exerciseCount;
}

List<CalendarProgramDay> calendarProgramDays(Map<String, dynamic> program) {
  final rawDays = program['days'];
  if (rawDays is! List) return const [];
  final result = <CalendarProgramDay>[];
  for (var i = 0; i < rawDays.length; i++) {
    final raw = rawDays[i];
    if (raw is! Map) continue;
    final day = Map<String, dynamic>.from(raw);
    final rawLabel = day['day_label'] ?? day['label'];
    final label = rawLabel?.toString().trim();
    final exercises = day['exercises'];
    result.add(
      CalendarProgramDay(
        dayIndex: resolveTrainingScheduleDayIndex(day, i),
        listIndex: i,
        label: label == null || label.isEmpty ? 'Day ${i + 1}' : label,
        exerciseCount: exercises is List ? exercises.length : 0,
      ),
    );
  }
  return result;
}

int? calendarProgramId(Map<String, dynamic> program) {
  final raw = program['program_id'];
  return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
}

class CalendarPlanSelection {
  const CalendarPlanSelection.rest() : isRest = true, day = null;
  const CalendarPlanSelection.training(this.day) : isRest = false;

  final bool isRest;
  final CalendarProgramDay? day;
}

class TrainingPlanPickerSheet extends StatelessWidget {
  const TrainingPlanPickerSheet({
    super.key,
    required this.days,
    required this.selected,
  });

  final List<CalendarProgramDay> days;
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
                onTap: () => Navigator.of(
                  context,
                ).pop(const CalendarPlanSelection.rest()),
              ),
              ...days.map(
                (day) => _PlanOption(
                  icon: Icons.fitness_center,
                  title: day.label,
                  subtitle:
                      '${day.exerciseCount} ${t.translate('training_calendar_exercises')}',
                  selected:
                      selected?.isTraining == true &&
                      selected?.trainingDayIndex == day.dayIndex,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(CalendarPlanSelection.training(day)),
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
