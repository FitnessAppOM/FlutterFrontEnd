import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_exercise_picker_sheet.dart';
import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_training_plan_ui.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/coach/progression_review_service.dart';

class ExpertPlanTemplateCreatePage extends StatefulWidget {
  const ExpertPlanTemplateCreatePage({
    super.key,
    required this.exerciseLibrary,
  });

  final List<ExercisePickerItem> exerciseLibrary;

  @override
  State<ExpertPlanTemplateCreatePage> createState() =>
      _ExpertPlanTemplateCreatePageState();
}

class _ExpertPlanTemplateCreatePageState
    extends State<ExpertPlanTemplateCreatePage> {
  String _title = '';
  bool _saving = false;
  late final List<_TemplateDayDraft> _days;

  @override
  void initState() {
    super.initState();
    _days = [_newDay(1)];
  }

  _TemplateDayDraft _newDay(int index) {
    return _TemplateDayDraft(label: 'Day $index', exercises: [_newExercise()]);
  }

  _TemplateExerciseDraft _newExercise() {
    return _TemplateExerciseDraft(
      exerciseId: widget.exerciseLibrary.first.id,
      sets: 3,
      reps: 10,
      rir: 2,
      weightKg: null,
    );
  }

  String _exerciseName(int exerciseId) {
    for (final exercise in widget.exerciseLibrary) {
      if (exercise.id == exerciseId) return exercise.name;
    }
    return 'Select exercise';
  }

  Future<void> _pickExercise(_TemplateExerciseDraft exercise) async {
    final picked = await showExercisePickerSheet(
      context: context,
      options: widget.exerciseLibrary,
      selectedId: exercise.exerciseId > 0 ? exercise.exerciseId : null,
    );
    if (picked == null || !mounted) return;
    setState(() => exercise.exerciseId = picked.id);
  }

  void _addDay() {
    if (_saving || _days.length >= 7) return;
    setState(() => _days.add(_newDay(_days.length + 1)));
  }

  void _showError(String message) {
    AppToast.show(context, message, type: AppToastType.error);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.trim();
    if (title.isEmpty) {
      _showError('Add a template title.');
      return;
    }
    if (_days.isEmpty) {
      _showError('Add at least one day.');
      return;
    }

    final payloadDays = <Map<String, dynamic>>[];
    for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) {
      final day = _days[dayIndex];
      if (day.exercises.isEmpty) {
        _showError('Day ${dayIndex + 1} must include at least one exercise.');
        return;
      }
      final exercises = <Map<String, dynamic>>[];
      for (
        var exerciseIndex = 0;
        exerciseIndex < day.exercises.length;
        exerciseIndex++
      ) {
        final exercise = day.exercises[exerciseIndex];
        if (exercise.exerciseId <= 0) {
          _showError(
            'Day ${dayIndex + 1}, exercise ${exerciseIndex + 1}: invalid exercise.',
          );
          return;
        }
        if (exercise.sets < 1 || exercise.reps < 1) {
          _showError(
            'Day ${dayIndex + 1}, exercise ${exerciseIndex + 1}: sets/reps must be at least 1.',
          );
          return;
        }
        exercises.add({
          'exercise_id': exercise.exerciseId,
          'sets': exercise.sets,
          'reps': exercise.reps,
          'rir': exercise.rir,
          'weight_kg': exercise.weightKg,
        });
      }
      payloadDays.add({
        'day_label': day.label.trim().isEmpty
            ? 'Day ${dayIndex + 1}'
            : day.label.trim(),
        'exercises': exercises,
      });
    }

    setState(() => _saving = true);
    try {
      final result = await ProgressionReviewService.createPlanTemplate(
        title: title,
        days: payloadDays,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _buildDay(int dayIndex) {
    final day = _days[dayIndex];
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(24)),
      child: TaqaTrainingDaySection(
        dayNumber: dayIndex + 1,
        dayName: day.label,
        enabled: !_saving,
        onDayNameChanged: (value) => setState(() => day.label = value),
        onDelete: _days.length > 1
            ? () => setState(() => _days.removeAt(dayIndex))
            : null,
        exercises: List.generate(day.exercises.length, (exerciseIndex) {
          final exercise = day.exercises[exerciseIndex];
          return TaqaTrainingExerciseCard(
            exerciseName: _exerciseName(exercise.exerciseId),
            onExerciseTap: _saving ? null : () => _pickExercise(exercise),
            onDelete: !_saving && day.exercises.length > 1
                ? () => setState(() => day.exercises.removeAt(exerciseIndex))
                : null,
            metricFields: [
              TaqaTrainingNumberInput(
                label: 'Sets',
                initialValue: exercise.sets,
                minValue: 1,
                maxValue: 20,
                enabled: !_saving,
                onChanged: (value) =>
                    setState(() => exercise.sets = value ?? exercise.sets),
              ),
              TaqaTrainingWeightInput(
                initialValue: exercise.weightKg,
                enabled: !_saving,
                onChanged: (value) => setState(() => exercise.weightKg = value),
              ),
              TaqaTrainingNumberInput(
                label: 'Reps',
                initialValue: exercise.reps,
                minValue: 1,
                maxValue: 200,
                enabled: !_saving,
                onChanged: (value) =>
                    setState(() => exercise.reps = value ?? exercise.reps),
              ),
              TaqaTrainingNumberInput(
                label: 'RIR',
                initialValue: exercise.rir,
                minValue: 0,
                maxValue: 6,
                allowNull: true,
                enabled: !_saving,
                onChanged: (value) => setState(() => exercise.rir = value),
              ),
            ],
          );
        }),
        onAddExercise: _saving
            ? null
            : () => setState(() => day.exercises.add(_newExercise())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: const TaqaPageAppBar(title: 'Create Plan Template'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: TaqaUiScale.insetsLTRB(16, 12, 17, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TaqaClientDashboardTitleText('Template title'),
                    SizedBox(height: TaqaUiScale.h(4)),
                    TaqaTrainingDayNameField(
                      initialValue: _title,
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _title = value),
                    ),
                    SizedBox(height: TaqaUiScale.h(20)),
                    ...List.generate(_days.length, _buildDay),
                    TaqaOutlineTagButton(
                      label: '+ Add Day',
                      width: TaqaUiScale.w(76),
                      height: TaqaUiScale.h(20),
                      onTap: _saving || _days.length >= 7 ? null : _addDay,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: TaqaUiScale.insetsLTRB(16, 10, 17, 16),
              decoration: BoxDecoration(
                color: TaqaUiColors.lightGray,
                border: Border(
                  top: BorderSide(
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: TaqaFilledButton(
                label: 'Save Template',
                loading: _saving,
                onTap: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateDayDraft {
  _TemplateDayDraft({required this.label, required this.exercises});

  String label;
  final List<_TemplateExerciseDraft> exercises;
}

class _TemplateExerciseDraft {
  _TemplateExerciseDraft({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.rir,
    required this.weightKg,
  });

  int exerciseId;
  int sets;
  int reps;
  int? rir;
  double? weightKg;
}
