import 'dart:convert';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../consents/consent_manager.dart';
import '../../core/account_storage.dart';
import '../metrics/daily_metrics_sync.dart';

class StepsService {
  final Health _health = Health();
  static const _manualKey = "manual_steps_entries";

  num _valueToNum(dynamic value) {
    if (value is num) return value;
    if (value is NumericHealthValue) return value.numericValue;
    if (value is HealthValue) {
      final dynamic numeric = (value as dynamic).numericValue;
      if (numeric is num) return numeric;
    }
    return num.tryParse(value.toString()) ?? 0;
  }

  Future<int> fetchTodaySteps() async {
    final manual = await _loadManualEntries();
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    // Prefer manual override when present.
    if (manual.containsKey(todayKey)) {
      return manual[todayKey]!;
    }

    final granted = await ConsentManager.requestAllHealth();
    if (!granted) {
      // Debug: permission was denied or unavailable.
      // ignore: avoid_print
      print("StepsService: authorization not granted for steps.");
      return manual[todayKey] ?? 0;
    }

    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    try {
      // Prefer the API that already aggregates steps.
      try {
        final total = await _health.getTotalStepsInInterval(start, end);
        if (total != null) {
          // ignore: avoid_print
          print("StepsService: total steps via getTotalStepsInInterval = $total");
          return total;
        }
      } catch (e) {
        // ignore: avoid_print
        print("StepsService: getTotalStepsInInterval failed: $e");
      }

      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.STEPS],
      );
      // Debug: inspect returned samples.
      // ignore: avoid_print
      print("StepsService: fetched ${data.length} step samples from $start to $end");

      final steps = data
          .where((e) => e.type == HealthDataType.STEPS)
          .fold<int>(0, (sum, e) => sum + _valueToNum(e.value).toInt());
      // ignore: avoid_print
      print("StepsService: total steps computed = $steps");
      return steps;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("StepsService: steps fetch failed, falling back to manual: $e");
      return manual[todayKey] ?? 0;
    }
  }

  Future<Map<DateTime, int>> fetchDailySteps({
    required DateTime start,
    required DateTime end,
  }) async {
    final granted = await ConsentManager.requestAllHealth();
    if (!granted) return {};

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.STEPS],
      );

      final Map<DateTime, int> totals = {};
      for (final s in data.where((e) => e.type == HealthDataType.STEPS)) {
        final num steps = _valueToNum(s.value);
        final dt = s.dateFrom ?? DateTime.now();
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        final current = totals[dayKey] ?? 0;
        totals[dayKey] = current + steps.toInt();
      }

      // Override with manual entries when provided.
      final manual = await _loadManualEntries();
      manual.forEach((day, steps) {
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day))) {
          totals[day] = steps;
        }
      });
      return totals;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("StepsService: daily steps fetch failed, returning manual data: $e");
      final manual = await _loadManualEntries();
      return manual;
    }
  }

  Future<int> fetchStepsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final map = await fetchDailySteps(start: start, end: end);
    return map[start] ?? 0;
  }

  Future<int> fetchStepsBetween(DateTime start, DateTime end) async {
    final granted = await ConsentManager.requestAllHealth();
    if (!granted) return 0;

    try {
      final total = await _health.getTotalStepsInInterval(start, end);
      if (total != null) return total;
    } catch (_) {
      // Fall back to manual sum below
    }

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.STEPS],
      );
      final steps = data
          .where((e) => e.type == HealthDataType.STEPS)
          .fold<int>(0, (sum, e) => sum + _valueToNum(e.value).toInt());
      return steps;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveManualEntry(DateTime day, int steps) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    existing[normalized] = steps;
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
