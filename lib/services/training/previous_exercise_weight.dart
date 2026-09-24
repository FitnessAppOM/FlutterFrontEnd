import 'dart:convert';

double? previousCompletedExerciseWeight(Map<String, dynamic> exercise) {
  final compliance =
      _asMap(exercise['program_compliance']) ?? _asMap(exercise['compliance']);
  if (compliance == null || compliance['completed'] != true) return null;

  final loggedAt = compliance['logged_at'];
  if (loggedAt is! String || loggedAt.trim().isEmpty) return null;

  final rawWeight = compliance['weight_used'];
  final weight = rawWeight is num
      ? rawWeight.toDouble()
      : double.tryParse(rawWeight?.toString() ?? '');
  return weight != null && weight > 0 ? weight : null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      return _asMap(jsonDecode(value));
    } catch (_) {
      return null;
    }
  }
  return null;
}
