import 'dart:convert';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../consents/consent_manager.dart';
import '../core/account_storage.dart';
import 'daily_metrics_sync.dart';

class SleepService {
  final Health _health = Health();
  static const _manualKey = "manual_sleep_entries";

  Future<bool> _ensurePermission() async {
    // Request steps + sleep + calories in one prompt to avoid multiple sheets.
    return ConsentManager.requestAllHealth();
  }

  Future<double> fetchSleepHoursLast24h() async {
    final manual = await _loadManualEntries();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final ok = await _ensurePermission();
    if (!ok) {
      return manual[todayKey] ?? 0;
    }

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: const [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_IN_BED,
        ],
      );

      double totalHours = 0;
      for (final s in samples.where((e) =>
          e.type == HealthDataType.SLEEP_ASLEEP ||
          e.type == HealthDataType.SLEEP_IN_BED)) {
        final minutes = _minutesForSample(s);
        totalHours += minutes / 60.0;
      }

      if (manual.containsKey(todayKey)) return manual[todayKey]!;
      return totalHours;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("SleepService: sleep fetch failed, falling back to manual: $e");
      return manual[todayKey] ?? 0;
    }
  }

  /// Returns a map of midnight DateTime -> hours slept for that day.
  Future<Map<DateTime, double>> fetchDailySleep({
    required DateTime start,
    required DateTime end,
  }) async {
    final ok = await _ensurePermission();
    if (!ok) return {};

    try {
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: const [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_IN_BED,
        ],
      );

      final Map<DateTime, double> totals = {};
      for (final s in samples.where((e) =>
          e.type == HealthDataType.SLEEP_ASLEEP ||
          e.type == HealthDataType.SLEEP_IN_BED)) {
        final minutes = _minutesForSample(s);
        final dt = s.dateFrom ?? DateTime.now();
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        totals[dayKey] = (totals[dayKey] ?? 0) + minutes / 60.0;
      }

      // Manual entries override the day's value.
      final manual = await _loadManualEntries();
      manual.forEach((day, hours) {
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) &&
            !day.isAfter(DateTime(end.year, end.month, end.day))) {
          totals[day] = hours;
        }
      });
      return totals;
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("SleepService: daily sleep fetch failed, returning manual data: $e");
      final manual = await _loadManualEntries();
      return manual;
    }
  }

  Future<double> fetchSleepForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final map = await fetchDailySleep(start: start, end: end);
    return map[start] ?? 0;
  }

  double _minutesForSample(HealthDataPoint s) {
    if (s.dateFrom != null && s.dateTo != null) {
      final mins = s.dateTo!.difference(s.dateFrom!).inMinutes;
      if (mins > 0) return mins.toDouble();
    }
    return double.tryParse((s.value ?? "0").toString()) ?? 0;
  }

  Future<void> saveManualEntry(DateTime day, double hours) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    existing[normalized] = hours;
    final encoded = existing.map((k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}", v));
    final key = await _scopedKey(_manualKey);
    await sp.setString(key, jsonEncode(encoded));
  }

  Future<Map<DateTime, double>> _loadManualEntries() async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_manualKey);
    final raw = sp.getString(key);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final Map<DateTime, double> result = {};
    decoded.forEach((k, v) {
      final parts = k.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          result[DateTime(y, m, d)] = (v as num).toDouble();
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
