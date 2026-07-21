import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_exercise_picker_sheet.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_training_plan_ui.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/coach/progression_review_service.dart';
import '../services/training/training_service.dart';
import '../core/user_friendly_error.dart';

class ExpertTrainingPlanReviewPage extends StatefulWidget {
  const ExpertTrainingPlanReviewPage({
    super.key,
    required this.clientUserId,
    required this.clientName,
    required this.activeProgram,
    this.trainingPlanError,
    this.clientAvatarUrl,
    this.clientActivityStatus,
  });

  final int clientUserId;
  final String clientName;
  final Map<String, dynamic> activeProgram;
  final String? trainingPlanError;
  final String? clientAvatarUrl;
  final String? clientActivityStatus;

  @override
  State<ExpertTrainingPlanReviewPage> createState() =>
      _ExpertTrainingPlanReviewPageState();
}

class _ExpertTrainingPlanReviewPageState
    extends State<ExpertTrainingPlanReviewPage> {
  bool _loadingExercises = true;
  bool _saving = false;
  bool _verifying = false;
  String? _exerciseLoadError;
  late Map<String, dynamic> _activeProgram;
  late List<_PlanDayDraft> _originalDays;
  late List<_PlanDayDraft> _draftDays;
  late int _plannedDaysPerWeek;
  List<ExercisePickerItem> _exerciseLibrary = const [];
  final Map<String, int> _exerciseIdByName = <String, int>{};
  bool _didCheckPlan = false;

  @override
  void initState() {
    super.initState();
    _activeProgram = Map<String, dynamic>.from(widget.activeProgram);
    _originalDays = _buildDraftDays(_activeProgram['days']);
    _draftDays = _cloneDays(_originalDays);
    _plannedDaysPerWeek = _toInt(_activeProgram['training_days_per_week']);
    _loadExerciseLibrary();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<_PlanDayDraft> _buildDraftDays(dynamic rawDays) {
    final days = _mapList(rawDays);
    days.sort(
      (a, b) => _toInt(a['day_index']).compareTo(_toInt(b['day_index'])),
    );
    return days
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key + 1;
          final dayMap = entry.value;
          final rawLabel = (dayMap['day_label'] ?? '').toString().trim();
          final label = rawLabel.isEmpty ? 'Day $index' : rawLabel;
          final rawExercises = _mapList(dayMap['exercises']);
          final exercises = rawExercises
              .map((exercise) {
                final exerciseName = (exercise['exercise_name'] ?? '')
                    .toString()
                    .trim();
                final weightKg = _toNullableDouble(exercise['weight_kg']);
                return _PlanExerciseDraft(
                  exerciseId: _toInt(exercise['exercise_id'], fallback: 0),
                  exerciseName: exerciseName,
                  sets: _toInt(exercise['sets'], fallback: 3).clamp(1, 20),
                  reps: _toInt(exercise['reps'], fallback: 10).clamp(1, 200),
                  rir: exercise['rir'] == null
                      ? null
                      : _toInt(exercise['rir']).clamp(0, 6),
                  weightKg: (weightKg != null && weightKg >= 0)
                      ? weightKg
                      : null,
                );
              })
              .toList(growable: true);
          return _PlanDayDraft(dayLabel: label, exercises: exercises);
        })
        .toList(growable: true);
  }

  List<_PlanDayDraft> _cloneDays(List<_PlanDayDraft> source) {
    return source
        .map((day) {
          return _PlanDayDraft(
            dayLabel: day.dayLabel,
            exercises: day.exercises
                .map((exercise) {
                  return _PlanExerciseDraft(
                    exerciseId: exercise.exerciseId,
                    exerciseName: exercise.exerciseName,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    rir: exercise.rir,
                    weightKg: exercise.weightKg,
                  );
                })
                .toList(growable: true),
          );
        })
        .toList(growable: true);
  }

  String _daysSignature(List<_PlanDayDraft> days) {
    final chunks = <String>[];
    for (final day in days) {
      chunks.add(day.dayLabel.trim());
      for (final exercise in day.exercises) {
        chunks.add(
          '${exercise.exerciseId}|${exercise.exerciseName}|${exercise.sets}|${exercise.reps}|${exercise.rir ?? ''}|${exercise.weightKg ?? ''}',
        );
      }
      chunks.add('::');
    }
    return chunks.join(';');
  }

  bool _isDirty() {
    return _daysSignature(_draftDays) != _daysSignature(_originalDays);
  }

  Map<String, dynamic>? _navigationResult() {
    if (!_didCheckPlan) return null;
    return {'activeProgram': _activeProgram, 'didCheck': true};
  }

  Future<void> _closePage() async {
    Navigator.of(context).pop(_navigationResult());
  }

  String _activePlanSource() {
    final source = (_activeProgram['plan_source'] ?? '').toString().trim();
    if (source == 'ai_generated' ||
        source == 'expert_created' ||
        source == 'ai_coach' ||
        source == 'coach_edited') {
      return source;
    }
    final createdBy = (_activeProgram['created_by'] ?? '').toString().trim();
    return createdBy == 'expert' ? 'expert_created' : 'ai_generated';
  }

  bool _activePlanVerified() {
    final raw = _activeProgram['expert_verified'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = (raw ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  bool _needsVerification() {
    if (_activeProgram.isEmpty) return false;
    return _activePlanSource() == 'ai_generated' && !_activePlanVerified();
  }

  Future<void> _loadExerciseLibrary() async {
    setState(() {
      _loadingExercises = true;
      _exerciseLoadError = null;
    });
    try {
      final raw = await TrainingService.fetchAllExercises(
        limit: 1500,
        offset: 0,
      );
      final options = <ExercisePickerItem>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final id = _toInt(item['exercise_id']);
        final name = (item['exercise_name'] ?? '').toString().trim();
        if (id <= 0 || name.isEmpty) continue;
        options.add(ExercisePickerItem(id: id, name: name));
      }
      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      _exerciseIdByName
        ..clear()
        ..addEntries(
          options.map((item) => MapEntry(_normalizeName(item.name), item.id)),
        );

      for (final day in _draftDays) {
        for (final exercise in day.exercises) {
          if (exercise.exerciseId > 0) continue;
          final mappedId =
              _exerciseIdByName[_normalizeName(exercise.exerciseName)];
          if (mappedId != null && mappedId > 0) {
            exercise.exerciseId = mappedId;
          }
        }
      }
      for (final day in _originalDays) {
        for (final exercise in day.exercises) {
          if (exercise.exerciseId > 0) continue;
          final mappedId =
              _exerciseIdByName[_normalizeName(exercise.exerciseName)];
          if (mappedId != null && mappedId > 0) {
            exercise.exerciseId = mappedId;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _exerciseLibrary = options;
        _loadingExercises = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exerciseLoadError = userFriendlyErrorMessage(e);
        _loadingExercises = false;
      });
    }
  }

  void _resetDraft() {
    setState(() {
      _draftDays = _cloneDays(_originalDays);
    });
  }

  bool _draftIsValid() {
    if (_draftDays.isEmpty || _draftDays.length > 7) return false;
    for (final day in _draftDays) {
      if (day.exercises.isEmpty) return false;
      for (final ex in day.exercises) {
        if (ex.exerciseId <= 0) return false;
        if (ex.sets < 1 || ex.sets > 20) return false;
        if (ex.reps < 1 || ex.reps > 200) return false;
        if (ex.rir != null && (ex.rir! < 0 || ex.rir! > 6)) return false;
      }
    }
    return true;
  }

  Future<void> _verifyOnly() async {
    if (!_needsVerification() || _isDirty() || _verifying) return;
    setState(() => _verifying = true);
    try {
      final result = await ProgressionReviewService.markClientTrainingPlanVerified(
        clientUserId: widget.clientUserId,
      );
      if (!mounted) return;
      // 'noop' means there was nothing to verify -- don't claim success.
      final verified = (result['status'] ?? '').toString() == 'verified';
      setState(() {
        _verifying = false;
        _didCheckPlan = true;
        if (verified) {
          _activeProgram = <String, dynamic>{
            ..._activeProgram,
            'expert_verified': true,
            'expert_verified_at':
                (result['verified_at'] ??
                        DateTime.now().toUtc().toIso8601String())
                    .toString(),
            'plan_state': 'verified',
          };
        }
      });
      AppToast.show(
        context,
        verified ? 'Plan verified.' : 'This plan does not need verification.',
        type: verified ? AppToastType.success : AppToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      final msg = userFriendlyErrorMessage(e);
      AppToast.show(
        context,
        msg.isEmpty ? 'Failed to verify plan.' : msg,
        type: AppToastType.error,
      );
    }
  }

  Future<void> _confirmChanges() async {
    if (_saving || !_draftIsValid() || !_isDirty()) return;
    // Guard: the payload sends numeric exercise ids resolved from the loaded
    // library. If the library is still loading or failed to load, ids may be
    // unresolved/stale and the save would fail on the backend. Block instead of
    // sending a bad plan.
    if (_loadingExercises ||
        _exerciseLoadError != null ||
        _exerciseLibrary.isEmpty) {
      AppToast.show(
        context,
        'Exercise list is still loading. Please wait a moment and try again.',
        type: AppToastType.info,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payloadDays = <Map<String, dynamic>>[];
      for (var dayIndex = 0; dayIndex < _draftDays.length; dayIndex++) {
        final day = _draftDays[dayIndex];
        payloadDays.add({
          'day_label': day.dayLabel.trim().isEmpty
              ? 'Day ${dayIndex + 1}'
              : day.dayLabel.trim(),
          'exercises': day.exercises
              .map((exercise) {
                return {
                  'exercise_id': exercise.exerciseId,
                  'sets': exercise.sets,
                  'reps': exercise.reps,
                  'rir': exercise.rir,
                  'weight_kg': exercise.weightKg,
                };
              })
              .toList(growable: false),
        });
      }
      await ProgressionReviewService.createClientTrainingPlan(
        clientUserId: widget.clientUserId,
        days: payloadDays,
        archiveExisting: true,
      );
      if (!mounted) return;
      final syncedDays = _draftDays
          .asMap()
          .entries
          .map((entry) {
            final dayIdx = entry.key + 1;
            final day = entry.value;
            return {
              'day_index': dayIdx,
              'day_label': day.dayLabel.trim().isEmpty
                  ? 'Day $dayIdx'
                  : day.dayLabel.trim(),
              'exercises': day.exercises
                  .map((exercise) {
                    final name = _exerciseLibrary
                        .firstWhere(
                          (item) => item.id == exercise.exerciseId,
                          orElse: () => ExercisePickerItem(
                            id: exercise.exerciseId,
                            name: exercise.exerciseName,
                          ),
                        )
                        .name;
                    return {
                      'exercise_id': exercise.exerciseId,
                      'exercise_name': name,
                      'sets': exercise.sets,
                      'reps': exercise.reps,
                      'rir': exercise.rir,
                      'weight_kg': exercise.weightKg,
                    };
                  })
                  .toList(growable: false),
            };
          })
          .toList(growable: false);

      final updatedProgram = <String, dynamic>{
        ..._activeProgram,
        'created_by': 'expert',
        'plan_source': _activePlanSource() == 'ai_generated'
            ? 'ai_coach'
            : 'coach_edited',
        'expert_verified': true,
        'expert_verified_at': DateTime.now().toUtc().toIso8601String(),
        'plan_state': _activePlanSource() == 'ai_generated'
            ? 'ai_coach'
            : 'coach_edited',
        'training_days_per_week': _draftDays.length,
        'days': syncedDays,
      };
      setState(() {
        _saving = false;
        _didCheckPlan = true;
        _activeProgram = updatedProgram;
        _plannedDaysPerWeek = _draftDays.length;
        _originalDays = _cloneDays(_draftDays);
      });
      AppToast.show(context, 'Changes saved.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = userFriendlyErrorMessage(e);
      AppToast.show(
        context,
        msg.isEmpty ? 'Failed to save changes.' : msg,
        type: AppToastType.error,
      );
      return;
    }
  }

  void _addDay() {
    if (_draftDays.length >= 7) return;
    final fallback = _exerciseLibrary.isNotEmpty
        ? _exerciseLibrary.first
        : null;
    setState(() {
      final index = _draftDays.length + 1;
      _draftDays.add(
        _PlanDayDraft(
          dayLabel: 'Day $index',
          exercises: [
            _PlanExerciseDraft(
              exerciseId: fallback?.id ?? 0,
              exerciseName: fallback?.name ?? '',
              sets: 3,
              reps: 10,
              rir: 2,
            ),
          ],
        ),
      );
    });
  }

  String _exerciseNameForId(int exerciseId) {
    for (final option in _exerciseLibrary) {
      if (option.id == exerciseId) return option.name;
    }
    return '';
  }

  String _exerciseDisplayName(_PlanExerciseDraft exercise) {
    final selectedName = _exerciseNameForId(exercise.exerciseId);
    if (selectedName.isNotEmpty) return selectedName;
    final draftName = exercise.exerciseName.trim();
    return draftName.isEmpty ? 'Select exercise' : draftName;
  }

  Future<void> _pickExercise(_PlanExerciseDraft exercise) async {
    final picked = await showExercisePickerSheet(
      context: context,
      options: _exerciseLibrary,
      selectedId: exercise.exerciseId > 0 ? exercise.exerciseId : null,
    );
    if (picked == null || !mounted) return;
    setState(() {
      exercise.exerciseId = picked.id;
      exercise.exerciseName = picked.name;
    });
  }

  Widget _buildDayCard(int dayIndex) {
    final day = _draftDays[dayIndex];
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(24)),
      child: TaqaTrainingDaySection(
        dayNumber: dayIndex + 1,
        dayName: day.dayLabel,
        enabled: !(_saving || _verifying),
        onDayNameChanged: (value) => setState(() => day.dayLabel = value),
        onDelete: _draftDays.length > 1
            ? () => setState(() => _draftDays.removeAt(dayIndex))
            : null,
        exercises: List.generate(day.exercises.length, (exIndex) {
          final ex = day.exercises[exIndex];
          return TaqaTrainingExerciseCard(
            exerciseName: _exerciseDisplayName(ex),
            onExerciseTap:
                !(_saving || _verifying) && _exerciseLibrary.isNotEmpty
                ? () => _pickExercise(ex)
                : null,
            onDelete: !(_saving || _verifying) && day.exercises.length > 1
                ? () => setState(() => day.exercises.removeAt(exIndex))
                : null,
            metricFields: [
              TaqaTrainingNumberInput(
                label: 'Sets',
                initialValue: ex.sets,
                minValue: 1,
                maxValue: 20,
                enabled: !(_saving || _verifying),
                onChanged: (value) =>
                    setState(() => ex.sets = value ?? ex.sets),
              ),
              TaqaTrainingWeightInput(
                initialValue: ex.weightKg,
                enabled: !(_saving || _verifying),
                onChanged: (value) => setState(() => ex.weightKg = value),
              ),
              TaqaTrainingNumberInput(
                label: 'Reps',
                initialValue: ex.reps,
                minValue: 1,
                maxValue: 200,
                enabled: !(_saving || _verifying),
                onChanged: (value) =>
                    setState(() => ex.reps = value ?? ex.reps),
              ),
              TaqaTrainingNumberInput(
                label: 'RIR',
                initialValue: ex.rir,
                minValue: 0,
                maxValue: 6,
                allowNull: true,
                enabled: !(_saving || _verifying),
                onChanged: (value) => setState(() => ex.rir = value),
              ),
            ],
          );
        }),
        onAddExercise: (_saving || _verifying || _exerciseLibrary.isEmpty)
            ? null
            : () {
                final fallback = _exerciseLibrary.first;
                setState(() {
                  day.exercises.add(
                    _PlanExerciseDraft(
                      exerciseId: fallback.id,
                      exerciseName: fallback.name,
                      sets: 3,
                      reps: 10,
                      rir: 2,
                    ),
                  );
                });
              },
      ),
    );
  }

  Widget _buildScrollableActions({
    required bool dirty,
    required bool canConfirm,
    required bool canVerifyOnly,
  }) {
    if (dirty || _saving) {
      return Row(
        children: [
          Expanded(
            child: TaqaTextActionButton(
              label: 'Reset',
              onTap: !_saving && !_verifying ? _resetDraft : null,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(8)),
          Expanded(
            child: TaqaFilledButton(
              label: 'Confirm',
              onTap: canConfirm ? _confirmChanges : null,
              loading: _saving,
              height: 45,
            ),
          ),
        ],
      );
    }

    return TaqaFilledButton(
      label: 'Verify',
      onTap: canVerifyOnly ? _verifyOnly : null,
      loading: _verifying,
      height: 45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _isDirty();
    final validDraft = _draftIsValid();
    final needsVerification = _needsVerification();
    final canVerifyOnly =
        needsVerification && !dirty && !_saving && !_verifying;
    final libraryReady =
        !_loadingExercises &&
        _exerciseLoadError == null &&
        _exerciseLibrary.isNotEmpty;
    final canConfirm =
        dirty && validDraft && libraryReady && !_saving && !_verifying;

    return PopScope<Map<String, dynamic>?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_navigationResult());
      },
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        appBar: TaqaPageAppBar(
          title: 'Client Training Plan',
          leading: TaqaBackButton(onPressed: _closePage),
        ),
        body: _loadingExercises
            ? const Center(child: TaqaLoadingIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: TaqaUiScale.insetsLTRB(16, 12, 17, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TaqaExpertClientCard(
                                name: widget.clientName,
                                avatarUrl: widget.clientAvatarUrl,
                                status: widget.clientActivityStatus,
                                showStatus: (widget.clientActivityStatus ?? '')
                                    .trim()
                                    .isNotEmpty,
                                subtitle: 'User ID: ${widget.clientUserId}',
                                details: [
                                  'Days/week: ${_plannedDaysPerWeek > 0 ? _plannedDaysPerWeek : _draftDays.length}',
                                ],
                                alerts: const [],
                                footer:
                                    needsVerification ||
                                        (_exerciseLoadError ?? '').isNotEmpty ||
                                        _draftDays.isEmpty
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (needsVerification) ...[
                                            const TaqaClientAlertText(
                                              text:
                                                  'Training plan pending verification',
                                            ),
                                          ],
                                          if (_exerciseLoadError != null &&
                                              _exerciseLoadError!
                                                  .isNotEmpty) ...[
                                            if (needsVerification)
                                              SizedBox(
                                                height: TaqaUiScale.h(6),
                                              ),
                                            TaqaClientAlertText(
                                              text: _exerciseLoadError!,
                                            ),
                                          ],
                                          if (_draftDays.isEmpty) ...[
                                            if (needsVerification ||
                                                (_exerciseLoadError ?? '')
                                                    .isNotEmpty)
                                              SizedBox(
                                                height: TaqaUiScale.h(6),
                                              ),
                                            TaqaClientDashboardBodyText(
                                              widget.trainingPlanError ??
                                                  'No active training plan yet.',
                                              color: TaqaUiColors.charcoal
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ],
                                        ],
                                      )
                                    : null,
                              ),
                              SizedBox(height: TaqaUiScale.h(12)),
                              if (_draftDays.isNotEmpty) ...[
                                ...List.generate(
                                  _draftDays.length,
                                  _buildDayCard,
                                ),
                                TaqaOutlineTagButton(
                                  label: '+ Add Day',
                                  width: TaqaUiScale.w(76),
                                  height: TaqaUiScale.h(20),
                                  onTap:
                                      (_saving ||
                                          _verifying ||
                                          _draftDays.length >= 7)
                                      ? null
                                      : _addDay,
                                ),
                              ],
                              if (needsVerification && dirty) ...[
                                SizedBox(height: TaqaUiScale.h(10)),
                                const TaqaClientAlertText(
                                  text:
                                      'Reset edits to verify the AI plan only.',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (dirty || needsVerification || _saving || _verifying)
                        Container(
                          padding: TaqaUiScale.insetsLTRB(16, 10, 17, 16),
                          decoration: BoxDecoration(
                            color: TaqaUiColors.lightGray,
                            border: Border(
                              top: BorderSide(
                                color: TaqaUiColors.charcoal.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                          ),
                          child: _buildScrollableActions(
                            dirty: dirty,
                            canConfirm: canConfirm,
                            canVerifyOnly: canVerifyOnly,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlanDayDraft {
  _PlanDayDraft({required this.dayLabel, required this.exercises});

  String dayLabel;
  final List<_PlanExerciseDraft> exercises;
}

class _PlanExerciseDraft {
  _PlanExerciseDraft({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.rir,
    this.weightKg,
  });

  int exerciseId;
  String exerciseName;
  int sets;
  int reps;
  int? rir;
  double? weightKg;
}
