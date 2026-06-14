bool isOutdoorCyclingExerciseName(String? rawName) {
  final name = (rawName ?? '').trim().toLowerCase();
  if (name.isEmpty) return false;
  return name == 'outdoor cycling';
}

bool isTreadmillExerciseName(String? rawName) {
  final name = (rawName ?? '').trim().toLowerCase();
  if (name.isEmpty) return false;
  return name.contains('treadmill') || name.contains('treadmil');
}

String resolvedCardioAnimationUrl(String? exerciseName, String? animationUrl) {
  if (isOutdoorCyclingExerciseName(exerciseName)) return '';
  return (animationUrl ?? '').trim();
}

bool isIndoorCardioExerciseName(String? rawName) {
  final name = (rawName ?? '').trim().toLowerCase();
  if (name.isEmpty) return false;

  const keywords = <String>[
    'assault bike',
    'boxing',
    'elliptical',
    'eliptical',
    'rowing',
    'rowing machine',
    'rope',
    'jump rope',
    'battle rope',
    'battling rope',
    'treadmill',
    'treadmil',
  ];

  return keywords.any(name.contains);
}
