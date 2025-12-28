import 'dart:convert';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../consents/consent_manager.dart';
import '../core/account_storage.dart';
import 'daily_metrics_sync.dart';

class CaloriesService {
  final Health _health = Health();
  static const _manualKey = "manual_calories_entries";

  num _valueToNum(dynamic value) {
    if (value is num) return value;
    if (value is NumericHealthValue) return value.numericValue;
    if (value is HealthValue) {
      final dynamic numeric = (value as dynamic).numericValue;
      if (numeric is num) return numeric;
    }
    return num.tryParse(value.toString()) ?? 0;
  }

  Future<int> fetchTodayCalories() async {
    final manual = await _loadManualEntries();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final granted = await ConsentManager.requestAllHealth();
    if (!granted) return manual[todayKey] ?? 0;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      final calories = data
          .where((e) => e.type == HealthDataType.ACTIVE_ENERGY_BURNED)
          .fold<int>(0, (sum, e) => sum + _valueToNum(e.value).round());
      if (manual.containsKey(todayKey)) return manual[todayKey]!;
      return calories;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("CaloriesService: calories fetch failed, falling back to manual: $e");
      return manual[todayKey] ?? 0;
    }
  }

  /// Returns a map of midnight DateTime -> calories burned (kcal) for that day.
  Future<Map<DateTime, int>> fetchDailyCalories({
    required DateTime start,
    required DateTime end,
  }) async {
    final granted = await ConsentManager.requestAllHealth();
    if (!granted) return {};

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      final Map<DateTime, int> totals = {};
      for (final s in data.where((e) => e.type == HealthDataType.ACTIVE_ENERGY_BURNED)) {
        final num val = _valueToNum(s.value);
        final dt = s.dateFrom ?? DateTime.now();
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        final current = totals[dayKey] ?? 0;
        totals[dayKey] = current + val.round();
      }
      final manual = await _loadManualEntries();
      manual.forEach((day, kcal) {
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day))) {
          totals[day] = kcal;
        }
      });
      return totals;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("CaloriesService: daily calories fetch failed, returning manual data: $e");
      final manual = await _loadManualEntries();
      return manual;
    }
  }

  Future<int> fetchCaloriesForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final map = await fetchDailyCalories(start: start, end: end);
    return map[start] ?? 0;
  }

  Future<void> saveManualEntry(DateTime day, int calories) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    existing[normalized] = calories;
    final encoded = existing.map((k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}",
        v));
    final key = await _scopedKey(_manualKey);
    await sp.setString(key, jsonEncode(encoded));
  }

  Future<Map<DateTime, int>> _loadManualEntries() async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_manualKey);
    final raw = sp.getString(key);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final Map<DateTime, int> result = {};
    decoded.forEach((k, v) {
      final parts = k.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          result[DateTime(y, m, d)] = (v as num).toInt();
        }
      }
    });
    return result;
  }

  Future<void> _syncDailyMetrics() async {
    try {
      await DailyMetricsSync().pushToday();
    } catch (_) {
      // Ignore sync failures; manual data still stored locally.
    }
  }

  Future<String> _scopedKey(String base) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return base;
    return "${base}_u$userId";
  }
}
