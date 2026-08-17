import 'dart:convert';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../consents/consent_manager.dart';
import '../../core/account_storage.dart';
import '../metrics/daily_metrics_sync.dart';

class StepsService {
  final Health _health = Health();
  static const _manualKey = "manual_steps_entries";
  static const Duration _todayCacheTtl = Duration(seconds: 30);
  static final Map<String, _TodayStepsCacheEntry> _todayCache = {};
  static final Map<String, Future<int>> _todayInFlight = {};

  num _valueToNum(dynamic value) {
    if (value is num) return value;
    if (value is NumericHealthValue) return value.numericValue;
    if (value is HealthValue) {
      final dynamic numeric = (value as dynamic).numericValue;
      if (numeric is num) return numeric;
    }
    return num.tryParse(value.toString()) ?? 0;
  }

  Future<int> fetchTodaySteps({bool force = false}) async {
    final now = DateTime.now();
    final userId = await AccountStorage.getUserId();
    final cacheKey = _todayKey(userId, now);
    final cached = _todayCache[cacheKey];
    if (!force &&
        cached != null &&
        now.difference(cached.fetchedAt) < _todayCacheTtl) {
      return cached.value;
    }

    final active = _todayInFlight[cacheKey];
    if (active != null) return active;

    final operation = _fetchTodayStepsUncached();
    _todayInFlight[cacheKey] = operation;
    try {
      final value = await operation;
      _todayCache[cacheKey] = _TodayStepsCacheEntry(
        value: value,
        fetchedAt: DateTime.now(),
      );
      return value;
    } finally {
      if (identical(_todayInFlight[cacheKey], operation)) {
        _todayInFlight.remove(cacheKey);
      }
    }
  }

  Future<int> _fetchTodayStepsUncached() async {
    final manual = await _loadManualEntries();
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    // Prefer manual override when present.
    if (manual.containsKey(todayKey)) {
      return manual[todayKey]!;
    }

    final granted = await ConsentManager.requestHealthPermissionsJIT(
      steps: true,
      sleep: false,
      calories: false,
    );
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
          print(
            "StepsService: total steps via getTotalStepsInInterval = $total",
          );
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
      print(
        "StepsService: fetched ${data.length} step samples from $start to $end",
      );

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

  /// Returns the deduplicated step total for a single calendar day using the
  /// platform's aggregated API. On Health Connect this merges overlapping
  /// records from different sources instead of summing them. If the aggregate
  /// is unavailable or throws (older devices / no Health Connect), returns
  /// [fallback] (the raw per-sample sum) so a day that has data never shows 0.
  Future<int> _aggregatedStepsForDay(
    DateTime day, {
    required int fallback,
  }) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    try {
      final total = await _health.getTotalStepsInInterval(dayStart, dayEnd);
      if (total != null) return total;
    } catch (e) {
      // ignore: avoid_print
      print(
        "StepsService: getTotalStepsInInterval failed for $dayStart, using raw sum: $e",
      );
    }
    return fallback;
  }

  Future<Map<DateTime, int>> fetchDailySteps({
    required DateTime start,
    required DateTime end,
  }) async {
    final granted = await ConsentManager.requestHealthPermissionsJIT(
      steps: true,
      sleep: false,
      calories: false,
    );
    if (!granted) return {};

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [HealthDataType.STEPS],
      );

      // Build the set of days that actually have step data in the range, then
      // resolve each day's total via the aggregated API (getTotalStepsInInterval).
      // On Health Connect this deduplicates overlapping records from multiple
      // sources (phone pedometer + Health Connect's own record), which the raw
      // per-sample sum below would otherwise double-count. iOS HealthKit returns
      // the same already-merged total. Falls back to the raw sum per day if the
      // aggregate is unavailable (older devices / no Health Connect), so days
      // that show a value today never drop to zero.
      final Map<DateTime, int> rawTotals = {};
      for (final s in data.where((e) => e.type == HealthDataType.STEPS)) {
        final num steps = _valueToNum(s.value);
        final dt = s.dateFrom;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        rawTotals[dayKey] = (rawTotals[dayKey] ?? 0) + steps.toInt();
      }

      final Map<DateTime, int> totals = {};
      for (final dayKey in rawTotals.keys) {
        totals[dayKey] = await _aggregatedStepsForDay(
          dayKey,
          fallback: rawTotals[dayKey] ?? 0,
        );
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
      print(
        "StepsService: daily steps fetch failed, returning manual data: $e",
      );
      final manual = await _loadManualEntries();
      return manual;
    }
  }

  Future<int> fetchStepsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final map = await fetchDailySteps(start: start, end: end);
    return map[start] ?? 0;
  }

  Future<int> fetchStepsBetween(DateTime start, DateTime end) async {
    final granted = await ConsentManager.requestHealthPermissionsJIT(
      steps: true,
      sleep: false,
      calories: false,
    );
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
    final encoded = existing.map(
      (k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}",
        v,
      ),
    );
    final key = await _scopedKey(_manualKey);
    await sp.setString(key, jsonEncode(encoded));
    await _invalidateTodayCacheIfNeeded(normalized);
  }

  Future<void> clearManualEntry(DateTime day) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    if (existing.remove(normalized) == null) return;
    await _invalidateTodayCacheIfNeeded(normalized);
    final key = await _scopedKey(_manualKey);
    if (existing.isEmpty) {
      await sp.remove(key);
      return;
    }
    final encoded = existing.map(
      (k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}",
        v,
      ),
    );
    await sp.setString(key, jsonEncode(encoded));
  }

  Future<Map<DateTime, int>> getManualEntries() async {
    return _loadManualEntries();
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

  static String _todayKey(int? userId, DateTime day) {
    return '${userId ?? 0}:${day.year}-${day.month}-${day.day}';
  }

  Future<void> _invalidateTodayCacheIfNeeded(DateTime day) async {
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    if (day != normalizedToday) return;
    final userId = await AccountStorage.getUserId();
    _todayCache.remove(_todayKey(userId, now));
  }
}

class _TodayStepsCacheEntry {
  const _TodayStepsCacheEntry({required this.value, required this.fetchedAt});

  final int value;
  final DateTime fetchedAt;
}
