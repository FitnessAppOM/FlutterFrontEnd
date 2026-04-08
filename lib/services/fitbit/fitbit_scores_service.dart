class FitbitScoresSummary {
  final int? sleepScore;
  final int? readinessScore;
  final int? stressManagementScore;

  const FitbitScoresSummary({
    required this.sleepScore,
    required this.readinessScore,
    required this.stressManagementScore,
  });

  bool get hasAny =>
      sleepScore != null ||
      readinessScore != null ||
      stressManagementScore != null;
}
