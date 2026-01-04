import 'dart:async';
import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../services/training_service.dart';
import 'exercise_feedback_sheet.dart';

class ExerciseSessionSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onFinished;

  const ExerciseSessionSheet({
    super.key,
    required this.exercise,
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

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => seconds++);
    });
  }

  String get _time =>
      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

  Future<void> _startExercise() async {
    // Only start locally; defer server start until we actually finish.
    setState(() => started = true);
    _startTimer();
  }

  Future<void> _finishExercise() async {
    if (submitting) return;

    setState(() => submitting = true);
    timer?.cancel();

    if (!startRecorded) {
      await TrainingService.startExercise(
        widget.exercise['program_exercise_id'],
      );
      startRecorded = true;
    }

    final int finalSets =
        int.tryParse(setsCtrl.text) ?? widget.exercise['sets'];
    final int finalReps =
        int.tryParse(repsCtrl.text) ?? widget.exercise['reps'];

    final double? weight = double.tryParse(weightCtrl.text);
    if (weight != null && weight > 0) {
      await TrainingService.saveWeight(
        widget.exercise['program_exercise_id'],
        weight,
      );
    }

    await TrainingService.finishExercise(
      programExerciseId: widget.exercise['program_exercise_id'],
      sets: finalSets,
      reps: finalReps,
      rir: rir.round(),
      durationSeconds: seconds,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseFeedbackSheet(
        programExerciseId: widget.exercise['program_exercise_id'],
        exerciseName: widget.exercise['exercise_name'],
        onDone: () {
          widget.onFinished();
          Navigator.pop(context); // close ExerciseSessionSheet
        },
      ),
    );
  }

  void _cancelSession() {
    timer?.cancel();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    timer?.cancel();
    weightCtrl.dispose();
    setsCtrl.dispose();
    repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? animPath = widget.exercise['animation_rel_path'];
    final String instructions = widget.exercise['instructions'] ?? '';
    final viewInsets = MediaQuery.of(context).viewInsets;
    final t = AppLocalizations.of(context);

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
                            label:
                                "${widget.exercise['sets']} x ${widget.exercise['reps']}",
                          ),
                          _SessionChip(
                            icon: Icons.bolt,
                            label:
                                "${t.translate("training_rir_label")} ${widget.exercise['rir']}",
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
                const SizedBox(height: 16),
                if (instructions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              t.translate("training_instructions_title"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          instructions,
                          style:
                              const TextStyle(color: Colors.white70, height: 1.5),
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
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
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
