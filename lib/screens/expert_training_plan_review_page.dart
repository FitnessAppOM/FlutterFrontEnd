import 'package:flutter/material.dart';

import '../services/coach/progression_review_service.dart';
import '../services/training/training_service.dart';
import '../theme/app_theme.dart';
import '../widgets/training/exercise_picker_sheet.dart';

class ExpertTrainingPlanReviewPage extends StatefulWidget {
  const ExpertTrainingPlanReviewPage({
    super.key,
    required this.clientUserId,
    required this.clientName,
    required this.activeProgram,
    this.trainingPlanError,
  });

  final int clientUserId;
  final String clientName;
  final Map<String, dynamic> activeProgram;
  final String? trainingPlanError;

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
    return days.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final dayMap = entry.value;
      final rawLabel = (dayMap['day_label'] ?? '').toString().trim();
      final label = rawLabel.isEmpty ? 'Day $index' : rawLabel;
      final rawExercises = _mapList(dayMap['exercises']);
      final exercises = rawExercises.map((exercise) {
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
          weightKg: (weightKg != null && weightKg >= 0) ? weightKg : null,
        );
      }).toList(growable: true);
      return _PlanDayDraft(
        dayLabel: label,
        exercises: exercises,
      );
    }).toList(growable: true);
  }

  List<_PlanDayDraft> _cloneDays(List<_PlanDayDraft> source) {
    return source.map((day) {
      return _PlanDayDraft(
        dayLabel: day.dayLabel,
        exercises: day.exercises.map((exercise) {
          return _PlanExerciseDraft(
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.exerciseName,
            sets: exercise.sets,
            reps: exercise.reps,
            rir: exercise.rir,
            weightKg: exercise.weightKg,
          );
        }).toList(growable: true),
      );
    }).toList(growable: true);
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
    return {
      'activeProgram': _activeProgram,
      'didCheck': true,
    };
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

  String _activePlanState() {
    final raw = (_activeProgram['plan_state'] ?? '').toString().trim();
    if (raw == 'ai_generated' ||
        raw == 'verified' ||
        raw == 'expert_created' ||
        raw == 'ai_coach' ||
        raw == 'coach_edited') {
      return raw;
    }
    final source = _activePlanSource();
    if (source == 'expert_created' ||
        source == 'ai_coach' ||
        source == 'coach_edited') {
      return source;
    }
    return _activePlanVerified() ? 'verified' : 'ai_generated';
  }

  bool _needsVerification() {
    if (_activeProgram.isEmpty) return false;
    return _activePlanSource() == 'ai_generated' && !_activePlanVerified();
  }

  String _planStateLabel() {
    switch (_activePlanState()) {
      case 'coach_edited':
      case 'expert_created':
        return 'Coach/editted';
      case 'ai_coach':
        return 'AI/Coach';
      case 'verified':
        return 'Verified by coach';
      default:
        return 'AI';
    }
  }

  Color _planStateColor() {
    switch (_activePlanState()) {
      case 'coach_edited':
      case 'expert_created':
        return const Color(0xFF66E0A3);
      case 'ai_coach':
        return const Color(0xFF4BE4C7);
      case 'verified':
        return const Color(0xFF74B9FF);
      default:
        return const Color(0xFF5FD8FF);
    }
  }

  Future<void> _loadExerciseLibrary() async {
    setState(() {
      _loadingExercises = true;
      _exerciseLoadError = null;
    });
    try {
      final raw = await TrainingService.fetchAllExercises(limit: 1500, offset: 0);
      final options = <ExercisePickerItem>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final id = _toInt(item['exercise_id']);
        final name = (item['exercise_name'] ?? '').toString().trim();
        if (id <= 0 || name.isEmpty) continue;
        options.add(ExercisePickerItem(id: id, name: name));
      }
      options.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _exerciseIdByName
        ..clear()
        ..addEntries(
          options.map((item) => MapEntry(_normalizeName(item.name), item.id)),
        );

      for (final day in _draftDays) {
        for (final exercise in day.exercises) {
          if (exercise.exerciseId > 0) continue;
          final mappedId = _exerciseIdByName[_normalizeName(exercise.exerciseName)];
          if (mappedId != null && mappedId > 0) {
            exercise.exerciseId = mappedId;
          }
        }
      }
      for (final day in _originalDays) {
        for (final exercise in day.exercises) {
          if (exercise.exerciseId > 0) continue;
          final mappedId = _exerciseIdByName[_normalizeName(exercise.exerciseName)];
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
        _exerciseLoadError = e.toString().replaceFirst('Exception: ', '');
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
      await ProgressionReviewService.markClientTrainingPlanVerified(
        clientUserId: widget.clientUserId,
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _didCheckPlan = true;
        _activeProgram = <String, dynamic>{
          ..._activeProgram,
          'expert_verified': true,
          'expert_verified_at': DateTime.now().toUtc().toIso8601String(),
          'plan_state': 'verified',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan verified.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg.isEmpty ? 'Failed to verify plan.' : msg)));
    }
  }

  Future<void> _confirmChanges() async {
    if (_saving || !_draftIsValid() || !_isDirty()) return;
    setState(() => _saving = true);
    try {
      final payloadDays = <Map<String, dynamic>>[];
      for (var dayIndex = 0; dayIndex < _draftDays.length; dayIndex++) {
        final day = _draftDays[dayIndex];
        payloadDays.add({
          'day_label': day.dayLabel.trim().isEmpty
              ? 'Day ${dayIndex + 1}'
              : day.dayLabel.trim(),
          'exercises': day.exercises.map((exercise) {
            return {
              'exercise_id': exercise.exerciseId,
              'sets': exercise.sets,
              'reps': exercise.reps,
              'rir': exercise.rir,
              'weight_kg': exercise.weightKg,
            };
          }).toList(growable: false),
        });
      }
      await ProgressionReviewService.createClientTrainingPlan(
        clientUserId: widget.clientUserId,
        days: payloadDays,
        archiveExisting: true,
      );
      if (!mounted) return;
      final syncedDays = _draftDays.asMap().entries.map((entry) {
        final dayIdx = entry.key + 1;
        final day = entry.value;
        return {
          'day_index': dayIdx,
          'day_label': day.dayLabel.trim().isEmpty ? 'Day $dayIdx' : day.dayLabel.trim(),
          'exercises': day.exercises.map((exercise) {
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
          }).toList(growable: false),
        };
      }).toList(growable: false);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg.isEmpty ? 'Failed to save changes.' : msg)));
      return;
    }
  }

  void _addDay() {
    if (_draftDays.length >= 7) return;
    final fallback = _exerciseLibrary.isNotEmpty ? _exerciseLibrary.first : null;
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

  Widget _buildExercisePickerField({
    required _PlanExerciseDraft exercise,
    required bool enabled,
  }) {
    final selectedName = _exerciseNameForId(exercise.exerciseId);
    final displayName = selectedName.isNotEmpty
        ? selectedName
        : (exercise.exerciseName.trim().isNotEmpty
              ? exercise.exerciseName.trim()
              : 'Select exercise');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled
          ? () async {
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
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Exercise',
          isDense: true,
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: displayName == 'Select exercise'
                ? Colors.white54
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStateBadge() {
    final color = _planStateColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _planStateLabel(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final day = _draftDays[dayIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: day.dayLabel,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Day ${dayIndex + 1}',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (value) => day.dayLabel = value,
                ),
              ),
              if (_draftDays.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _saving || _verifying
                      ? null
                      : () => setState(() => _draftDays.removeAt(dayIndex)),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(day.exercises.length, (exIndex) {
            final ex = day.exercises[exIndex];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildExercisePickerField(
                    exercise: ex,
                    enabled:
                        !(_saving || _verifying) && _exerciseLibrary.isNotEmpty,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Sets',
                          initialValue: ex.sets,
                          minValue: 1,
                          maxValue: 20,
                          enabled: !(_saving || _verifying),
                          onChanged: (value) => ex.sets = value ?? ex.sets,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _NumberField(
                          label: 'Reps',
                          initialValue: ex.reps,
                          minValue: 1,
                          maxValue: 200,
                          enabled: !(_saving || _verifying),
                          onChanged: (value) => ex.reps = value ?? ex.reps,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _NumberField(
                          label: 'RIR',
                          initialValue: ex.rir,
                          minValue: 0,
                          maxValue: 6,
                          allowNull: true,
                          enabled: !(_saving || _verifying),
                          onChanged: (value) => ex.rir = value,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: (_saving || _verifying || day.exercises.length <= 1)
                            ? null
                            : () {
                                setState(() => day.exercises.removeAt(exIndex));
                              },
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _WeightField(
                    initialValue: ex.weightKg,
                    enabled: !(_saving || _verifying),
                    onChanged: (value) => ex.weightKg = value,
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: (_saving || _verifying || _exerciseLibrary.isEmpty)
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
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _isDirty();
    final validDraft = _draftIsValid();
    final needsVerification = _needsVerification();
    final canVerifyOnly = needsVerification && !dirty && !_saving && !_verifying;
    final canConfirm = dirty && validDraft && !_saving && !_verifying;

    return PopScope<Map<String, dynamic>?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_navigationResult());
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          surfaceTintColor: Colors.transparent,
          title: const Text('Client Training Plan'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closePage,
          ),
        ),
        body: _loadingExercises
            ? const Center(child: CircularProgressIndicator())
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.clientName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    _buildStateBadge(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Days/week: ${_plannedDaysPerWeek > 0 ? _plannedDaysPerWeek : _draftDays.length}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                if (_exerciseLoadError != null &&
                                    _exerciseLoadError!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _exerciseLoadError!,
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (_draftDays.isEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.trainingPlanError ??
                                        'No active training plan yet.',
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_draftDays.isNotEmpty) ...[
                            ...List.generate(_draftDays.length, _buildDayCard),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: (_saving || _verifying || _draftDays.length >= 7)
                                    ? null
                                    : _addDay,
                                icon: const Icon(Icons.calendar_view_day_rounded),
                                label: const Text('Add day'),
                              ),
                            ),
                          ],
                          if (needsVerification && dirty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Reset edits to verify the AI plan only.',
                              style: TextStyle(
                                color: Color(0xFF5FD8FF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(color: Colors.white24),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: (!_saving && !_verifying && dirty)
                                  ? _resetDraft
                                  : null,
                              child: const Text('Reset'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: canVerifyOnly ? _verifyOnly : null,
                              child: _verifying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Verify'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: canConfirm ? _confirmChanges : null,
                              child: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Confirm'),
                            ),
                          ),
                        ),
                      ],
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

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
    required this.enabled,
    required this.onChanged,
    this.allowNull = false,
  });

  final String label;
  final int? initialValue;
  final int minValue;
  final int maxValue;
  final bool enabled;
  final bool allowNull;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : '${widget.initialValue}',
    );
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue == null ? '' : '${widget.initialValue}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(String raw) {
    final text = raw.trim();
    if (text.isEmpty && widget.allowNull) {
      widget.onChanged(null);
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    final clamped = parsed.clamp(widget.minValue, widget.maxValue);
    if (clamped != parsed) {
      _controller.text = '$clamped';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
      ),
      onChanged: _handleChange,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}

class _WeightField extends StatefulWidget {
  const _WeightField({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final double? initialValue;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final TextEditingController _controller;

  static const double _maxWeight = 1000;

  String _format(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialValue));
  }

  @override
  void didUpdateWidget(covariant _WeightField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _toDouble(_controller.text) != widget.initialValue) {
      _controller.text = _format(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _toDouble(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _handleChange(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed == null) return;
    if (parsed < 0) {
      widget.onChanged(0);
      return;
    }
    if (parsed > _maxWeight) {
      _controller.text = _format(_maxWeight);
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      widget.onChanged(_maxWeight);
      return;
    }
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Weight (kg)',
        hintText: 'Not set',
        isDense: true,
      ),
      onChanged: _handleChange,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
