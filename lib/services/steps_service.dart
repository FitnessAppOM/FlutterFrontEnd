import 'dart:convert';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../consents/consent_manager.dart';

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

    final granted = await ConsentManager.requestAllHealth();
    if (!granted) {
      // Debug: permission was denied or unavailable.
      // ignore: avoid_print
      print("StepsService: authorization not granted for steps.");
      return manual[todayKey] ?? 0;
    }

    final start = DateTime(now.year, now.month, now.day);
    final end = now;

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
    if (manual.containsKey(todayKey)) return manual[todayKey]!;
    return steps;
  }

  Future<Map<DateTime, int>> fetchDailySteps({
    required DateTime start,
    required DateTime end,
  }) async {
    final granted = await ConsentManager.requestAllHealth();
    if (!granted) return {};

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
  }

  Future<void> saveManualEntry(DateTime day, int steps) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    existing[normalized] = steps;
    final encoded = existing.map((k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}",
        v));
    await sp.setString(_manualKey, jsonEncode(encoded));
  }

  Future<Map<DateTime, int>> _loadManualEntries() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_manualKey);
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
}
