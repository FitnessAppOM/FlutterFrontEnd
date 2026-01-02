import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/training_service.dart';

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
    await TrainingService.startExercise(
      widget.exercise['program_exercise_id'],
    );
    setState(() => started = true);
    _startTimer();
  }

  Future<void> _finishExercise() async {
    timer?.cancel();

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
    );

    widget.onFinished();
    Navigator.pop(context);
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
    final String instructions =
        widget.exercise['instructions'] ?? '';

    Widget animationWidget = const Icon(
      Icons.fitness_center,
      size: 80,
      color: Colors.grey,
    );

    if (animPath != null && animPath.isNotEmpty) {
      // This will show the exact path in your Debug Console
      print("DEBUG: Trying to load asset: 'assets/$animPath'");

      animationWidget = SizedBox(
        height: 160,
        child: Image.asset(
          'assets/$animPath',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // This prints the error if the image fails to load
            print("ERROR loading GIF: $error");
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: animationWidget),
            const SizedBox(height: 12),

            Text(
              widget.exercise['exercise_name'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              "${widget.exercise['sets']} x ${widget.exercise['reps']} • RIR ${widget.exercise['rir']}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                instructions,
                style: const TextStyle(height: 1.4),
              ),
            ],

            const SizedBox(height: 20),

            if (!started)
              ElevatedButton(
                onPressed: _startExercise,
                child: const Text("Start Exercise"), // translate later
              ),

            if (started) ...[
              Center(
                child: Text(
                  _time,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: weightCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Weight (kg)",
                ),
              ),

              TextField(
                controller: setsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Performed Sets",
                ),
              ),

              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Performed Reps",
                ),
              ),

              const SizedBox(height: 12),

              Text("RIR: ${rir.round()}"),
              Slider(
                min: 0,
                max: 5,
                divisions: 5,
                value: rir,
                onChanged: (v) => setState(() => rir = v),
              ),

              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: _finishExercise,
                child: const Text("Finish Exercise"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
