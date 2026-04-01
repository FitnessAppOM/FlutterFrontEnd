class TrainingCalorieEstimator {
  static const double defaultWeightKg = 70.0;
  static const double strengthMet = 6.0;
  static const double cardioMet = 8.0;

  static int estimateCaloriesKcal({
    required int durationSeconds,
    required bool isCardio,
    required double weightKg,
  }) {
    final met = isCardio ? cardioMet : strengthMet;
    final safeSeconds = durationSeconds <= 0 ? 1 : durationSeconds;
    final hours = safeSeconds / 3600.0;
    final kcal = (met * weightKg * hours).round();
    return kcal.clamp(1, 5000);
  }
}
