const Set<String> timerBasedExerciseNames = {
  'l-sit hold',
  'side plank',
  'plank',
  'superman',
  'wall sit',
  'hollow rock',
};

bool isTimerBasedExercise(Map<String, dynamic> exercise) {
  if (exercise['is_timer_based'] == true) return true;
  if (exercise['set_input_mode']?.toString().trim().toLowerCase() == 'timer') {
    return true;
  }
  final name = (exercise['exercise_name'] ?? exercise['name'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  return timerBasedExerciseNames.contains(name);
}
