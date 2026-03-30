import 'dart:convert';
import 'dart:io';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../consents/consent_manager.dart';
import '../../core/account_storage.dart';
import '../metrics/daily_metrics_sync.dart';

class SleepDayMetrics {
  const SleepDayMetrics({
    required this.inBedMinutes,
    required this.asleepMinutes,
    required this.awakeMinutes,
    required this.lightMinutes,
    required this.deepMinutes,
    required this.remMinutes,
  });

  final int inBedMinutes;
  final int asleepMinutes;
  final int awakeMinutes;
  final int lightMinutes;
  final int deepMinutes;
  final int remMinutes;

  int get stageTotalMinutes => lightMinutes + deepMinutes + remMinutes;
  int get totalSleepMinutes =>
      asleepMinutes > 0 ? asleepMinutes : stageTotalMinutes;
  bool get hasStageData => stageTotalMinutes > 0;
  bool get hasAnyData =>
      inBedMinutes > 0 ||
      asleepMinutes > 0 ||
      awakeMinutes > 0 ||
      lightMinutes > 0 ||
      deepMinutes > 0 ||
      remMinutes > 0;

  double get efficiency =>
      inBedMinutes > 0 ? (totalSleepMinutes / inBedMinutes) : 0.0;

  double get lightPct =>
      stageTotalMinutes > 0 ? (lightMinutes / stageTotalMinutes) : 0.0;
  double get deepPct =>
      stageTotalMinutes > 0 ? (deepMinutes / stageTotalMinutes) : 0.0;
  double get remPct =>
      stageTotalMinutes > 0 ? (remMinutes / stageTotalMinutes) : 0.0;
}

class SleepService {
  final Health _health = Health();
  static const _manualKey = "manual_sleep_entries";
  static const List<HealthDataType> _sleepMetricTypes = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
  ];
  static final List<HealthDataAccess> _sleepMetricPermissions = List.filled(
    _sleepMetricTypes.length,
    HealthDataAccess.READ,
  );

  Future<bool> _ensurePermission() async {
    // Request steps + sleep + calories in one prompt to avoid multiple sheets.
    return ConsentManager.requestAllHealth();
  }

  Future<bool> _ensureSleepMetricPermission() async {
    if (!Platform.isIOS) return false;
    try {
      var granted =
          await _health.hasPermissions(
            _sleepMetricTypes,
            permissions: _sleepMetricPermissions,
          ) ??
          false;
      if (!granted) {
        granted = await _health.requestAuthorization(
          _sleepMetricTypes,
          permissions: _sleepMetricPermissions,
        );
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<SleepDayMetrics?> _fetchSleepMetricsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _sleepMetricTypes,
      );

      int inBed = 0;
      int asleep = 0;
      int awake = 0;
      int light = 0;
      int deep = 0;
      int rem = 0;

      for (final s in samples) {
        final minutes = _minutesForSample(s).round();
        if (minutes <= 0) continue;
        switch (s.type) {
          case HealthDataType.SLEEP_IN_BED:
            inBed += minutes;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            asleep += minutes;
            break;
          case HealthDataType.SLEEP_AWAKE:
          case HealthDataType.SLEEP_AWAKE_IN_BED:
          case HealthDataType.SLEEP_OUT_OF_BED:
            awake += minutes;
            break;
          case HealthDataType.SLEEP_LIGHT:
            light += minutes;
            break;
          case HealthDataType.SLEEP_DEEP:
            deep += minutes;
            break;
          case HealthDataType.SLEEP_REM:
            rem += minutes;
            break;
          default:
            break;
        }
      }

      if (asleep <= 0) {
        asleep = light + deep + rem;
      }
      if (inBed <= 0) {
        final inferredInBed = asleep + awake;
        inBed = inferredInBed > 0 ? inferredInBed : asleep;
      }

      final metrics = SleepDayMetrics(
        inBedMinutes: inBed,
        asleepMinutes: asleep,
        awakeMinutes: awake,
        lightMinutes: light,
        deepMinutes: deep,
        remMinutes: rem,
      );
      if (!metrics.hasAnyData) return null;
      return metrics;
    } catch (_) {
      return null;
    }
  }

  Future<SleepDayMetrics?> fetchSleepMetricsLast24h() async {
    final granted = await _ensureSleepMetricPermission();
    if (!granted) return null;
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    return _fetchSleepMetricsInRange(start: start, end: now);
  }

  Future<SleepDayMetrics?> fetchSleepMetricsForDay(DateTime day) async {
    final granted = await _ensureSleepMetricPermission();
    if (!granted) return null;
    final start = DateTime(day.year, day.month, day.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    return _fetchSleepMetricsInRange(start: start, end: end);
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
        types: const [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
      );

      double asleepHours = 0;
      double inBedHours = 0;
      for (final s in samples.where(
        (e) =>
            e.type == HealthDataType.SLEEP_ASLEEP ||
            e.type == HealthDataType.SLEEP_IN_BED,
      )) {
        final minutes = _minutesForSample(s);
        if (s.type == HealthDataType.SLEEP_ASLEEP) {
          asleepHours += minutes / 60.0;
        } else if (s.type == HealthDataType.SLEEP_IN_BED) {
          inBedHours += minutes / 60.0;
        }
      }
      final totalHours = asleepHours > 0 ? asleepHours : inBedHours;

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
        types: const [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
      );

      final Map<DateTime, double> asleepTotals = {};
      final Map<DateTime, double> inBedTotals = {};
      for (final s in samples.where(
        (e) =>
            e.type == HealthDataType.SLEEP_ASLEEP ||
            e.type == HealthDataType.SLEEP_IN_BED,
      )) {
        final minutes = _minutesForSample(s);
        final dt = s.dateFrom;
        final dayKey = DateTime(dt.year, dt.month, dt.day);
        if (s.type == HealthDataType.SLEEP_ASLEEP) {
          asleepTotals[dayKey] = (asleepTotals[dayKey] ?? 0) + minutes / 60.0;
        } else if (s.type == HealthDataType.SLEEP_IN_BED) {
          inBedTotals[dayKey] = (inBedTotals[dayKey] ?? 0) + minutes / 60.0;
        }
      }
      final Map<DateTime, double> totals = {};
      final allKeys = <DateTime>{...asleepTotals.keys, ...inBedTotals.keys};
      for (final key in allKeys) {
        final asleep = asleepTotals[key] ?? 0;
        final inBed = inBedTotals[key] ?? 0;
        totals[key] = asleep > 0 ? asleep : inBed;
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
      print(
        "SleepService: daily sleep fetch failed, returning manual data: $e",
      );
      final manual = await _loadManualEntries();
      return manual;
    }
  }

  Future<double> fetchSleepForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final map = await fetchDailySleep(start: start, end: end);
    return map[start] ?? 0;
  }

  double _minutesForSample(HealthDataPoint s) {
    final mins = s.dateTo.difference(s.dateFrom).inMinutes;
    if (mins > 0) return mins.toDouble();
    return double.tryParse(s.value.toString()) ?? 0;
  }

  Future<void> saveManualEntry(DateTime day, double hours) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    existing[normalized] = hours;
    final encoded = existing.map(
      (k, v) => MapEntry(
        "${k.year}-${k.month.toString().padLeft(2, '0')}-${k.day.toString().padLeft(2, '0')}",
        v,
      ),
    );
    final key = await _scopedKey(_manualKey);
    await sp.setString(key, jsonEncode(encoded));
  }

  Future<Map<DateTime, double>> getManualEntries() async {
    return _loadManualEntries();
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
