import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';
import '../auth/profile_storage.dart';
import 'training_calorie_estimator.dart';

class TrainingCaloriesService {
  static const String _entriesKey = "training_estimated_calories_entries";

  Future<int> estimateCalories({
    required int durationSeconds,
    required bool isCardio,
  }) async {
    final weightKg =
        await _loadWeightKg() ?? TrainingCalorieEstimator.defaultWeightKg;
    return TrainingCalorieEstimator.estimateCaloriesKcal(
      durationSeconds: durationSeconds,
      isCardio: isCardio,
      weightKg: weightKg,
    );
  }

  Future<void> addEstimatedCaloriesForDay(DateTime day, int calories) async {
    if (calories <= 0) return;
    final entries = await _loadEntries();
    final key = _normalizeDay(day);
    entries[key] = (entries[key] ?? 0) + calories;
    await _saveEntries(entries);
  }

  Future<int> fetchEstimatedCaloriesForDay(DateTime day) async {
    final entries = await _loadEntries();
    return entries[_normalizeDay(day)] ?? 0;
  }

  Future<Map<DateTime, int>> fetchEstimatedCaloriesRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await _loadEntries();
    final startKey = _normalizeDay(start);
    final endKey = _normalizeDay(end);
    final out = <DateTime, int>{};
    entries.forEach((day, value) {
      if (day.isBefore(startKey) || day.isAfter(endKey) || value <= 0) return;
      out[day] = value;
    });
    return out;
  }

  Future<double?> _loadWeightKg() async {
    final profile = await ProfileStorage.loadProfile();
    if (profile == null) return null;
    final raw = profile['weight_kg'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  DateTime _normalizeDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  String _encodeDay(DateTime day) =>
      "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

  DateTime? _decodeDay(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<Map<DateTime, int>> _loadEntries() async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_entriesKey);
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};
    final out = <DateTime, int>{};
    decoded.forEach((k, v) {
      final day = _decodeDay(k);
      if (day == null) return;
      final value = v is num ? v.toInt() : int.tryParse(v.toString());
      if (value == null || value <= 0) return;
      out[day] = value;
    });
    return out;
  }

  Future<void> _saveEntries(Map<DateTime, int> entries) async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_entriesKey);
    final encoded = <String, int>{};
    entries.forEach((day, value) {
      if (value <= 0) return;
      encoded[_encodeDay(day)] = value;
    });
    await sp.setString(key, jsonEncode(encoded));
  }

  Future<String> _scopedKey(String base) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return base;
    return "${base}_u$userId";
  }
}
