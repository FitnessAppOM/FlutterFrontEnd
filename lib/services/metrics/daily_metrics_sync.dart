import 'dart:async';

import '../../core/account_storage.dart';
import '../diet/calories_service.dart';
import '../diet/diet_service.dart';
import 'daily_metrics_api.dart';
import '../health/sleep_service.dart';
import '../health/steps_service.dart';
import '../health/water_service.dart';
import '../health/health_recovery_load_service.dart';
import '../training/training_calories_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pulls device/dashboard values for historical days and pushes them to
/// the backend daily_metrics table for the current signed-in user.
/// Current day is intentionally skipped.
class DailyMetricsSync {
  final StepsService _steps = StepsService();
  final CaloriesService _calories = CaloriesService();
  final SleepService _sleep = SleepService();
  final WaterService _water = WaterService();
  final HealthRecoveryLoadService _recoveryLoad = HealthRecoveryLoadService();
  final TrainingCaloriesService _trainingCalories = TrainingCaloriesService();
  static const _lastPushKey = "daily_metrics_last_push_date";
  static const _localStartHour = 1; // 1:00 AM local device time
  static bool _syncInFlight = false;

  DateTime _effectiveLocalDay([DateTime? now]) {
    final reference = (now ?? DateTime.now()).subtract(
      const Duration(hours: _localStartHour),
    );
    return DateTime(reference.year, reference.month, reference.day);
  }

  Future<bool> pushForDate(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      throw Exception("NO_USER");
    }
    final target = DateTime(day.year, day.month, day.day);
    final today = _effectiveLocalDay();
    if (target == today) {
      return false;
    }

    // Fetch health metrics sequentially.
    // `ConsentManager.requestAllHealth()` uses a single in-flight guard; parallel
    // reads can make some metric calls return "not granted" and produce zeros.
    final steps = await _steps.fetchStepsForDay(target);
    final cardioCalories = await _calories.fetchCaloriesForDay(target);
    final estimatedTrainingCalories = await _trainingCalories
        .fetchEstimatedCaloriesForDay(target);
    final displayCalories = cardioCalories + estimatedTrainingCalories;
    final sleepHours = await _sleep.fetchSleepForDay(target);
    final sleepMetrics = await _sleep.fetchSleepMetricsForDay(target);
    final waterLiters = await _water.getIntakeForDay(target);
    final recoveryLoad = await _recoveryLoad.fetchSummary(target);

    final hasMeaningfulData = _hasMeaningfulDailyMetricsPayload(
      steps: steps,
      calories: displayCalories,
      sleepHours: sleepHours,
      sleepMinutesAsleep: sleepMetrics?.asleepMinutes,
      sleepMinutesInBed: sleepMetrics?.inBedMinutes,
      sleepMinutesAwake: sleepMetrics?.awakeMinutes,
      sleepMinutesLight: sleepMetrics?.lightMinutes,
      sleepMinutesDeep: sleepMetrics?.deepMinutes,
      sleepMinutesRem: sleepMetrics?.remMinutes,
      restingHr: recoveryLoad?.restingHeartRate,
      hrvMs: recoveryLoad?.hrvMs,
      activeMinutes: recoveryLoad?.activeMinutes,
      workoutMinutes: recoveryLoad?.workoutMinutes,
      heartZoneOutOfRangeMinutes: recoveryLoad?.zones?.outOfRangeMinutes,
      heartZoneFatBurnMinutes: recoveryLoad?.zones?.fatBurnMinutes,
      heartZoneCardioMinutes: recoveryLoad?.zones?.cardioMinutes,
      heartZonePeakMinutes: recoveryLoad?.zones?.peakMinutes,
      waterLiters: waterLiters,
    );
    if (!hasMeaningfulData) {
      // ignore: avoid_print
      print(
        "DailyMetricsSync: skip empty payload for ${target.toIso8601String().split('T').first} (steps=$steps calories=$displayCalories sleep=${sleepHours.toStringAsFixed(2)}h)",
      );
      return false;
    }

    await DailyMetricsApi.upsert(
      userId: userId,
      entryDate: target,
      steps: steps,
      calories: displayCalories,
      sleepHours: sleepHours,
      sleepMinutesAsleep: sleepMetrics?.asleepMinutes,
      sleepMinutesInBed: sleepMetrics?.inBedMinutes,
      sleepMinutesAwake: sleepMetrics?.awakeMinutes,
      sleepMinutesLight: sleepMetrics?.lightMinutes,
      sleepMinutesDeep: sleepMetrics?.deepMinutes,
      sleepMinutesRem: sleepMetrics?.remMinutes,
      restingHr: recoveryLoad?.restingHeartRate,
      hrvMs: recoveryLoad?.hrvMs,
      activeMinutes: recoveryLoad?.activeMinutes,
      workoutMinutes: recoveryLoad?.workoutMinutes,
      heartZoneOutOfRangeMinutes: recoveryLoad?.zones?.outOfRangeMinutes,
      heartZoneFatBurnMinutes: recoveryLoad?.zones?.fatBurnMinutes,
      heartZoneCardioMinutes: recoveryLoad?.zones?.cardioMinutes,
      heartZonePeakMinutes: recoveryLoad?.zones?.peakMinutes,
      waterLiters: waterLiters,
    );

    // Submit burn for this date so surplus is set (surplus = calories burned). Every submit overwrites.
    try {
      await DailyMetricsApi.submitBurn(
        userId: userId,
        caloriesBurned: cardioCalories,
        entryDate: target,
      );
      await DietService.fetchCurrentTargets(userId);
      DietService.notifyTargetsUpdatedAfterBurn();
    } catch (_) {
      // Ignore; diet page will refetch when opened; day summary uses backend surplus.
    }

    return true;
  }

  /// Pushes metrics for yesterday the first time the app opens on a new day.
  Future<bool> pushYesterdayIfNewDay() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return false;

    final yesterday = _effectiveLocalDay().subtract(const Duration(days: 1));
    return pushForDate(yesterday);
  }

  /// Retained for compatibility; current day writes are intentionally skipped.
  Future<void> pushToday() async {
    await pushForDate(DateTime.now());
  }

  /// Pushes and reconciles historical metrics for the current effective local day.
  Future<void> pushIfNewDay() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      final sp = await SharedPreferences.getInstance();
      final lastKey = _userScopedKey(userId);
      final todayKey = _dateKey(_effectiveLocalDay());

      await pushYesterdayIfNewDay();
      final backfillSettled = await backfillMissingIfNeeded();
      if (backfillSettled) {
        await sp.setString(lastKey, todayKey);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  /// Backfill missing or incomplete days in the last 7 days (excluding today).
  Future<bool> backfillMissingIfNeeded() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return true;

    final todayKey = _effectiveLocalDay();
    final start = todayKey.subtract(const Duration(days: 7));
    final end = todayKey.subtract(const Duration(days: 1));

    if (end.isBefore(start)) return true;

    DailyMetricsApi.clearCache();
    final existing = await DailyMetricsApi.fetchRange(
      userId: userId,
      start: start,
      end: end,
    );

    final missing = _findMissingOrIncompleteDays(
      existing: existing,
      start: start,
      end: end,
    );
    if (missing.isEmpty) return true;

    var failedDays = 0;
    for (final day in missing) {
      try {
        await pushForDate(day);
      } catch (e) {
        failedDays += 1;
        // ignore: avoid_print
        print(
          "DailyMetricsSync: push failed for ${day.toIso8601String().split('T').first}: $e",
        );
      }
    }
    if (failedDays > 0) {
      // ignore: avoid_print
      print(
        "DailyMetricsSync: backfill completed with $failedDays failed day(s) out of ${missing.length}.",
      );
    }

    DailyMetricsApi.clearCache();
    final refreshed = await DailyMetricsApi.fetchRange(
      userId: userId,
      start: start,
      end: end,
    );
    final stillMissing = _findMissingOrIncompleteDays(
      existing: refreshed,
      start: start,
      end: end,
    );
    return stillMissing.isEmpty;
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
  String _dateKey(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  bool _isPositiveNum(num? value) => value != null && value > 0;

  bool _hasMeaningfulDailyMetricsPayload({
    required int? steps,
    required int? calories,
    required double? sleepHours,
    required int? sleepMinutesAsleep,
    required int? sleepMinutesInBed,
    required int? sleepMinutesAwake,
    required int? sleepMinutesLight,
    required int? sleepMinutesDeep,
    required int? sleepMinutesRem,
    required int? restingHr,
    required double? hrvMs,
    required int? activeMinutes,
    required int? workoutMinutes,
    required int? heartZoneOutOfRangeMinutes,
    required int? heartZoneFatBurnMinutes,
    required int? heartZoneCardioMinutes,
    required int? heartZonePeakMinutes,
    required double? waterLiters,
  }) {
    final hasSleep =
        _isPositiveNum(sleepHours) ||
        _isPositiveNum(sleepMinutesAsleep) ||
        _isPositiveNum(sleepMinutesInBed) ||
        _isPositiveNum(sleepMinutesAwake) ||
        _isPositiveNum(sleepMinutesLight) ||
        _isPositiveNum(sleepMinutesDeep) ||
        _isPositiveNum(sleepMinutesRem);
    final hasActivity =
        _isPositiveNum(steps) ||
        _isPositiveNum(calories) ||
        _isPositiveNum(activeMinutes) ||
        _isPositiveNum(workoutMinutes) ||
        _isPositiveNum(heartZoneOutOfRangeMinutes) ||
        _isPositiveNum(heartZoneFatBurnMinutes) ||
        _isPositiveNum(heartZoneCardioMinutes) ||
        _isPositiveNum(heartZonePeakMinutes);
    final hasRecovery = _isPositiveNum(restingHr) || _isPositiveNum(hrvMs);
    final hasWater = _isPositiveNum(waterLiters);
    return hasSleep || hasActivity || hasRecovery || hasWater;
  }

  bool _isPersistedDailyMetricsRow(DailyMetricsEntry row) {
    return _hasMeaningfulDailyMetricsPayload(
      steps: row.steps,
      calories: row.calories,
      sleepHours: row.sleepHours,
      sleepMinutesAsleep: row.sleepMinutesAsleep,
      sleepMinutesInBed: row.sleepMinutesInBed,
      sleepMinutesAwake: row.sleepMinutesAwake,
      sleepMinutesLight: row.sleepMinutesLight,
      sleepMinutesDeep: row.sleepMinutesDeep,
      sleepMinutesRem: row.sleepMinutesRem,
      restingHr: row.restingHr,
      hrvMs: row.hrvMs,
      activeMinutes: row.activeMinutes,
      workoutMinutes: row.workoutMinutes,
      heartZoneOutOfRangeMinutes: row.heartZoneOutOfRangeMinutes,
      heartZoneFatBurnMinutes: row.heartZoneFatBurnMinutes,
      heartZoneCardioMinutes: row.heartZoneCardioMinutes,
      heartZonePeakMinutes: row.heartZonePeakMinutes,
      waterLiters: row.waterLiters,
    );
  }

  List<DateTime> _findMissingOrIncompleteDays({
    required Map<DateTime, DailyMetricsEntry> existing,
    required DateTime start,
    required DateTime end,
  }) {
    final missing = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final key = DateTime(cursor.year, cursor.month, cursor.day);
      final row = existing[key];
      if (row == null || !_isPersistedDailyMetricsRow(row)) {
        missing.add(key);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return missing;
  }
}
