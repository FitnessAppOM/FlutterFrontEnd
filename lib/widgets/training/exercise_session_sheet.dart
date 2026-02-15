import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_service.dart';
import 'exercise_feedback_sheet.dart';
import 'exercise_instruction_dialog.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../services/training/training_completion_storage.dart';
import '../../services/training/training_activity_service.dart';

class ExerciseSessionSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Set<String> completedExerciseNames;
  final VoidCallback onFinished;

  const ExerciseSessionSheet({
    super.key,
    required this.exercise,
    required this.completedExerciseNames,
    required this.onFinished,
  });

  @override
  State<ExerciseSessionSheet> createState() => _ExerciseSessionSheetState();
}

class _ExerciseSessionSheetState extends State<ExerciseSessionSheet> {
  bool started = false;
  bool submitting = false;
  bool startRecorded = false;

  int seconds = 0;
  Timer? timer;

  final weightCtrl = TextEditingController();
  final setsCtrl = TextEditingController();
  final repsCtrl = TextEditingController();

  double rir = 2;

  @override
  void initState() {
    super.initState();
    _prefillFromLastEntry();
    if (_shouldAutoShowInstructions()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openInstructionDialog();
      });
    }
  }

  void _prefillFromLastEntry() {
    final compliance = _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);

    final performedSets = compliance?['performed_sets'] ?? widget.exercise['performed_sets'];
    final performedReps = compliance?['performed_reps'] ?? widget.exercise['performed_reps'];
    final weightUsed = compliance?['weight_used'] ?? widget.exercise['weight_used'];
    final performedRir = compliance?['performed_rir'] ?? widget.exercise['performed_rir'];

    if (setsCtrl.text.isEmpty) {
      final text = _valueAsText(performedSets);
      if (text != null) setsCtrl.text = text;
    }
    if (repsCtrl.text.isEmpty) {
      final text = _valueAsText(performedReps);
      if (text != null) repsCtrl.text = text;
    }
    if (weightCtrl.text.isEmpty) {
      final text = _valueAsText(weightUsed);
      if (text != null) weightCtrl.text = text;
    }
    final rirValue = _valueAsDouble(performedRir);
    if (rirValue != null) {
      rir = rirValue.clamp(0, 3);
    }
  }

  Map<String, dynamic>? _extractCompliance(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _valueAsText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      if (value == 0) return null;
      final asInt = value.toInt();
      return (value == asInt) ? asInt.toString() : value.toString();
    }
    if (value is bool) return value ? "1" : null;
    return value.toString();
  }

  double? _valueAsDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    if (value is bool) return value ? 1 : 0;
    return null;
  }

  bool _shouldAutoShowInstructions() {
    final instructions = widget.exercise['instructions'] ?? '';
    if (instructions.toString().trim().isEmpty) return false;
    final rawName = (widget.exercise['exercise_name'] ?? '').toString().trim().toLowerCase();
    if (rawName.isNotEmpty && widget.completedExerciseNames.contains(rawName)) {
      return false;
    }
    return !_hasExistingEntry(widget.exercise);
  }

  bool _hasExistingEntry(Map<String, dynamic> exercise) {
    final entries = [
      exercise['program_compliance'],
      exercise['compliance'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
      exercise['completed'],
      exercise['is_completed'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
    ];
    return entries.any(_hasMeaningfulValue);
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  void _openInstructionDialog() {
    final instructions = (widget.exercise['instructions'] ?? '').toString();
    if (instructions.trim().isEmpty) return;
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => ExerciseInstructionDialog(
        title: t.translate("training_instructions_title"),
        instructions: instructions,
      ),
    );
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => seconds++);
      if (seconds % 5 == 0) {
        final sets = _currentSets();
        final reps = _currentReps();
        TrainingActivityService.updateSession(
          exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
          sets: sets,
          reps: reps,
          seconds: seconds,
        );
      }
    });
  }

  String get _time =>
      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

  Future<void> _startExercise() async {
    setState(() => started = true);
    _startTimer();
    await TrainingActivityService.startSession(
      exerciseName: (widget.exercise['exercise_name'] ?? '').toString(),
      sets: _currentSets(),
      reps: _currentReps(),
      seconds: seconds,
    );
    
    // Queue start action for sync (non-blocking)
    final programExerciseId = widget.exercise['program_exercise_id'];
    if (programExerciseId != null) {
      try {
        // Try to start on server immediately
        await TrainingService.startExercise(programExerciseId);
        startRecorded = true;
      } catch (e) {
        // If offline, queue for later sync
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionStart,
          programExerciseId: programExerciseId,
        );
        startRecorded = false; // Will be recorded when syncing
      }
    }
  }

  Future<void> _finishExercise() async {
    if (submitting) return;

    setState(() => submitting = true);
    timer?.cancel();
    await TrainingActivityService.stopSession();

    final t = AppLocalizations.of(context);
    final programExerciseId = widget.exercise['program_exercise_id'];
    bool needsSync = false;
    final now = DateTime.now(); // device local

    final int finalSets =
        int.tryParse(setsCtrl.text) ?? widget.exercise['sets'];
    final int finalReps =
        int.tryParse(repsCtrl.text) ?? widget.exercise['reps'];

    final double? weight = double.tryParse(weightCtrl.text);

    // Try to sync with server, but queue if offline
    try {
      // Start exercise if not already started
      if (!startRecorded) {
        try {
          await TrainingService.startExercise(programExerciseId, entryDate: now);
          startRecorded = true;
        } catch (e) {
          // Queue start action
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionStart,
            programExerciseId: programExerciseId,
            data: {"entry_date": "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}"},
          );
          needsSync = true;
        }
      }

      // Save weight if provided
      if (weight != null && weight > 0) {
        try {
          await TrainingService.saveWeight(programExerciseId, weight);
        } catch (e) {
          // Queue weight action
          await ExerciseActionQueue.queueAction(
            action: ExerciseActionQueue.actionWeight,
            programExerciseId: programExerciseId,
            data: {"weight": weight},
          );
          needsSync = true;
        }
      }

      // Finish exercise
      try {
        await TrainingService.finishExercise(
          programExerciseId: programExerciseId,
          sets: finalSets,
          reps: finalReps,
          rir: rir.round(),
          durationSeconds: seconds,
          entryDate: now,
        );
      } catch (e) {
        // Queue finish action
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionFinish,
          programExerciseId: programExerciseId,
          data: {
            "sets": finalSets,
            "reps": finalReps,
            "rir": rir.round(),
            "duration_seconds": seconds,
            "entry_date": "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
          },
        );
        needsSync = true;
      }
    } catch (e) {
      // If all fails, queue everything
      needsSync = true;
    }

    // Show message if queued for sync
    if (needsSync && mounted) {
      AppToast.show(
        context,
        t.translate("exercise_saved_offline") ?? "Exercise saved offline. Will sync when online.",
        type: AppToastType.info,
      );
    }

    // Record that user completed an exercise today (diet page can auto-set "training day" and lock "rest day")
    await TrainingCompletionStorage.recordExerciseCompletedToday();

    // Show feedback sheet (works offline)
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => ExerciseFeedbackSheet(
          programExerciseId: programExerciseId,
          exerciseName: widget.exercise['exercise_name'],
          onDone: () {
            widget.onFinished();
            Navigator.pop(context); // close ExerciseSessionSheet
          },
        ),
      );
    }
  }

  void _cancelSession() {
    timer?.cancel();
    TrainingActivityService.stopSession();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    timer?.cancel();
    TrainingActivityService.stopSession();
    weightCtrl.dispose();
    setsCtrl.dispose();
    repsCtrl.dispose();
    super.dispose();
  }

  int _currentSets() {
    final raw = int.tryParse(setsCtrl.text);
    if (raw != null && raw > 0) return raw;
    final ex = widget.exercise['sets'];
    if (ex is int) return ex;
    if (ex is String) return int.tryParse(ex) ?? 0;
    if (ex is num) return ex.toInt();
    return 0;
  }

  int _currentReps() {
    final raw = int.tryParse(repsCtrl.text);
    if (raw != null && raw > 0) return raw;
    final ex = widget.exercise['reps'];
    if (ex is int) return ex;
    if (ex is String) return int.tryParse(ex) ?? 0;
    if (ex is num) return ex.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final String? animPath = widget.exercise['animation_rel_path'];
    final String instructions = widget.exercise['instructions'] ?? '';
    final viewInsets = MediaQuery.of(context).viewInsets;
    final t = AppLocalizations.of(context);
    final compliance = _extractCompliance(widget.exercise['program_compliance']) ??
        _extractCompliance(widget.exercise['compliance']);
    final String? overrideSets = _valueAsText(
      compliance?['performed_sets'] ?? widget.exercise['performed_sets'],
    );
    final String? overrideReps = _valueAsText(
      compliance?['performed_reps'] ?? widget.exercise['performed_reps'],
    );
    final String setsLabel = overrideSets ?? widget.exercise['sets'].toString();
    final String repsLabel = overrideReps ?? widget.exercise['reps'].toString();
    final String? overrideRir = _valueAsText(
      compliance?['performed_rir'] ?? widget.exercise['performed_rir'],
    );
    final String rirLabel = overrideRir ?? widget.exercise['rir'].toString();

    Widget animationWidget = const Icon(
      Icons.fitness_center,
      size: 80,
      color: Colors.grey,
    );

    if (animPath != null && animPath.isNotEmpty) {
      final String gifUrl =
          "${TrainingService.baseUrl}/static/$animPath";

      animationWidget = SizedBox(
        height: 160,
        child: Image.network(
          gifUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.fitness_center,
              size: 80,
              color: Colors.grey,
            );
          },
        ),
      );
    }

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1325), Color(0xFF0B0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF162447), Color(0xFF0D1325)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: animationWidget,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.exercise['exercise_name'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _SessionChip(
                            icon: Icons.repeat,
                            label: "$setsLabel x $repsLabel",
                          ),
                          _SessionChip(
                            icon: Icons.bolt,
                            label: "${t.translate("training_rir_label")} $rirLabel",
                          ),
                          if (started)
                            _SessionChip(
                              icon: Icons.timer,
                              label: _time,
                              accent: Colors.blueAccent,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!started)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade400,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      t.translate("training_start_exercise"),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: _startExercise,
                  ),
                if (started) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate("training_session_title"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SessionChip(
                              icon: Icons.timer,
                              label: _time,
                              accent: Colors.blueAccent,
                            ),
                            _SessionChip(
                              icon: Icons.monitor_weight,
                              label: t.translate("training_log_weight_reps"),
                              accent: Colors.purpleAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              _inputStyle(t.translate("training_weight_label")),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: setsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              _inputStyle(t.translate("training_performed_sets")),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: repsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              _inputStyle(t.translate("training_performed_reps")),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t.translate("training_rir_label"),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              rir.round().toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          min: 0,
                          max: 3,
                          divisions: 3,
                          value: rir,
                          activeColor: Colors.greenAccent,
                          inactiveColor: Colors.white24,
                          onChanged: (v) => setState(() => rir = v),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: submitting ? null : _cancelSession,
                                child: Text(t.translate("common_cancel")),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade400,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: submitting ? null : _finishExercise,
                                child: submitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        t.translate("finish"),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (instructions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.04),
                            ),
                            icon: const Icon(Icons.menu_book),
                            label: Text(
                              t.translate("training_instructions_title"),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: _openInstructionDialog,
                          ),
                        ],
                    ],
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputStyle(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.greenAccent),
    ),
  );
}

class _SessionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _SessionChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (accent ?? Colors.white).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (accent ?? Colors.white).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ?? Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
