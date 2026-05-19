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

class _SleepDurationBucket {
  int asleepMinutes = 0;
  int lightMinutes = 0;
  int deepMinutes = 0;
  int remMinutes = 0;

  void addSample(HealthDataType type, int minutes) {
    switch (type) {
      case HealthDataType.SLEEP_ASLEEP:
        asleepMinutes += minutes;
        break;
      case HealthDataType.SLEEP_LIGHT:
        lightMinutes += minutes;
        break;
      case HealthDataType.SLEEP_DEEP:
        deepMinutes += minutes;
        break;
      case HealthDataType.SLEEP_REM:
        remMinutes += minutes;
        break;
      default:
        break;
    }
  }

  void merge(_SleepDurationBucket other) {
    asleepMinutes += other.asleepMinutes;
    lightMinutes += other.lightMinutes;
    deepMinutes += other.deepMinutes;
    remMinutes += other.remMinutes;
  }

  int get stageMinutes => lightMinutes + deepMinutes + remMinutes;
  int get preferredMinutes => asleepMinutes > 0 ? asleepMinutes : stageMinutes;
  double get preferredHours => preferredMinutes / 60.0;
}

class SleepService {
  final Health _health = Health();
  static const _manualKey = "manual_sleep_entries";
  static const List<HealthDataType> _sleepBasicTypes = [
    HealthDataType.SLEEP_ASLEEP,
  ];
  static const List<HealthDataType> _sleepStageTypes = [
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];
  static const List<HealthDataType> _sleepMetricTypesIos = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];
  static const List<HealthDataType> _sleepMetricTypesAndroid = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  List<HealthDataType> _sleepMetricTypesForPlatform() {
    if (Platform.isAndroid) return _sleepMetricTypesAndroid;
    return _sleepMetricTypesIos;
  }

  Future<bool> _ensurePermission() async {
    // Scope permission to sleep only so unrelated denied scopes (e.g. workout)
    // don't block sleep reads.
    return ConsentManager.requestHealthPermissionsJIT(
      steps: false,
      sleep: true,
      calories: false,
    );
  }

  Future<bool> _ensureSleepMetricPermission() async {
    try {
      // Don't re-prompt on Android — unified prompt already covered this.
      if (Platform.isAndroid &&
          await ConsentManager.isAndroidHealthPromptCached()) {
        return true;
      }
      final types = _sleepMetricTypesForPlatform();
      final permissions = List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
      );
      var granted =
          await _health.hasPermissions(types, permissions: permissions) ??
          false;
      if (!granted) {
        granted = await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureSleepStagePermission() async {
    try {
      if (Platform.isAndroid &&
          await ConsentManager.isAndroidHealthPromptCached()) {
        return true;
      }
      final permissions = List<HealthDataAccess>.filled(
        _sleepStageTypes.length,
        HealthDataAccess.READ,
      );
      var granted =
          await _health.hasPermissions(
            _sleepStageTypes,
            permissions: permissions,
          ) ??
          false;
      if (!granted) {
        granted = await _health.requestAuthorization(
          _sleepStageTypes,
          permissions: permissions,
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
      final types = _sleepMetricTypesForPlatform();
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
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
    final manualHours = manual[todayKey];

    // Manual entry for today explicitly overrides HealthKit/Health Connect.
    if (manualHours != null && manualHours > 0) {
      return manualHours;
    }

    try {
      final metricGranted = await _ensureSleepMetricPermission();
      if (metricGranted) {
        final now = DateTime.now();
        final start = now.subtract(const Duration(hours: 24));
        final metrics = await _fetchSleepMetricsInRange(start: start, end: now);
        final metricHours = (metrics?.totalSleepMinutes ?? 0) / 60.0;
        if (metricHours > 0) return metricHours;
      }
    } catch (_) {
      // Fall through to existing scoped sleep read path.
    }

    final ok = await _ensurePermission();
    if (!ok) {
      return manualHours ?? 0;
    }

    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final basicSamples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _sleepBasicTypes,
      );
      final bucket = _bucketFromSamples(basicSamples);

      if (bucket.asleepMinutes <= 0) {
        final stagePermission = await _ensureSleepStagePermission();
        if (stagePermission) {
          final stageSamples = await _health.getHealthDataFromTypes(
            startTime: start,
            endTime: now,
            types: _sleepStageTypes,
          );
          bucket.merge(_bucketFromSamples(stageSamples));
        }
      }
      final totalHours = bucket.preferredHours;

      return totalHours > 0 ? totalHours : (manualHours ?? 0);
    } catch (e) {
      // Unsupported platform/Health Connect missing—fallback to manual data.
      // ignore: avoid_print
      print("SleepService: sleep fetch failed, falling back to manual: $e");
      return manualHours ?? 0;
    }
  }

  /// Returns a map of midnight DateTime -> hours slept for that day.
  Future<Map<DateTime, double>> fetchDailySleep({
    required DateTime start,
    required DateTime end,
  }) async {
    final ok = await _ensurePermission();
    if (!ok) {
      final manual = await _loadManualEntries();
      return _manualEntriesInRange(manual, start: start, end: end);
    }

    try {
      final basicSamples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _sleepBasicTypes,
      );
      final buckets = _bucketsByDay(basicSamples);

      final hasAsleepData = buckets.values.any((b) => b.asleepMinutes > 0);
      if (!hasAsleepData) {
        final stagePermission = await _ensureSleepStagePermission();
        if (stagePermission) {
          final stageSamples = await _health.getHealthDataFromTypes(
            startTime: start,
            endTime: end,
            types: _sleepStageTypes,
          );
          final stageBuckets = _bucketsByDay(stageSamples);
          stageBuckets.forEach((day, bucket) {
            buckets.putIfAbsent(day, _SleepDurationBucket.new).merge(bucket);
          });
        }
      }

      final Map<DateTime, double> totals = {};
      buckets.forEach((day, bucket) {
        final hours = bucket.preferredHours;
        if (hours > 0) {
          totals[day] = hours;
        }
      });

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
      return _manualEntriesInRange(manual, start: start, end: end);
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

  _SleepDurationBucket _bucketFromSamples(Iterable<HealthDataPoint> samples) {
    final bucket = _SleepDurationBucket();
    for (final sample in samples) {
      final minutes = _minutesForSample(sample).round();
      if (minutes <= 0) continue;
      bucket.addSample(sample.type, minutes);
    }
    return bucket;
  }

  Map<DateTime, _SleepDurationBucket> _bucketsByDay(
    Iterable<HealthDataPoint> samples,
  ) {
    final buckets = <DateTime, _SleepDurationBucket>{};
    for (final sample in samples) {
      final minutes = _minutesForSample(sample).round();
      if (minutes <= 0) continue;
      final from = sample.dateFrom;
      final dayKey = DateTime(from.year, from.month, from.day);
      buckets
          .putIfAbsent(dayKey, _SleepDurationBucket.new)
          .addSample(sample.type, minutes);
    }
    return buckets;
  }

  Map<DateTime, double> _manualEntriesInRange(
    Map<DateTime, double> manual, {
    required DateTime start,
    required DateTime end,
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    final filtered = <DateTime, double>{};
    manual.forEach((day, hours) {
      final key = DateTime(day.year, day.month, day.day);
      if (!key.isBefore(from) && !key.isAfter(to)) {
        filtered[key] = hours;
      }
    });
    return filtered;
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

  Future<void> clearManualEntry(DateTime day) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await _loadManualEntries();
    final normalized = DateTime(day.year, day.month, day.day);
    if (existing.remove(normalized) == null) return;
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
