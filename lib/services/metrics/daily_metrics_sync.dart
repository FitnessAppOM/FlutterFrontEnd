import 'dart:async';

import '../../core/account_storage.dart';
import '../diet/calories_service.dart';
import '../diet/diet_service.dart';
import 'daily_metrics_api.dart';
import '../health/sleep_service.dart';
import '../health/steps_service.dart';
import '../health/water_service.dart';
import '../health/health_recovery_load_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pulls device/dashboard values for today and pushes them to the backend
/// daily_metrics table for the current signed-in user.
class DailyMetricsSync {
  final StepsService _steps = StepsService();
  final CaloriesService _calories = CaloriesService();
  final SleepService _sleep = SleepService();
  final WaterService _water = WaterService();
  final HealthRecoveryLoadService _recoveryLoad = HealthRecoveryLoadService();
  static const _lastPushKey = "daily_metrics_last_push_date";

  Future<void> pushForDate(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      throw Exception("NO_USER");
    }
    final target = DateTime(day.year, day.month, day.day);

    // Fetch health metrics sequentially.
    // `ConsentManager.requestAllHealth()` uses a single in-flight guard; parallel
    // reads can make some metric calls return "not granted" and produce zeros.
    final steps = await _steps.fetchStepsForDay(target);
    final calories = await _calories.fetchCaloriesForDay(target);
    final sleepHours = await _sleep.fetchSleepForDay(target);
    final sleepMetrics = await _sleep.fetchSleepMetricsForDay(target);
    final waterLiters = await _water.getIntakeForDay(target);
    final recoveryLoad = await _recoveryLoad.fetchSummary(target);

    await DailyMetricsApi.upsert(
      userId: userId,
      entryDate: target,
      steps: steps,
      calories: calories,
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
      heartZoneOutOfRangeMinutes: recoveryLoad?.zones?.outOfRangeMinutes,
      heartZoneFatBurnMinutes: recoveryLoad?.zones?.fatBurnMinutes,
      heartZoneCardioMinutes: recoveryLoad?.zones?.cardioMinutes,
      heartZonePeakMinutes: recoveryLoad?.zones?.peakMinutes,
      waterLiters: waterLiters,
    );

    // Submit burn for this date so surplus is set (surplus = calories burned). Every submit overwrites.
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    try {
      await DailyMetricsApi.submitBurn(
        userId: userId,
        caloriesBurned: calories,
        entryDate: target,
      );
      if (target == today) {
        await DietService.fetchCurrentTargets(userId);
        DietService.notifyTargetsUpdatedAfterBurn();
      }
    } catch (_) {
      // Ignore; diet page will refetch when opened; day summary uses backend surplus.
    }

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userScopedKey(userId), _dateKey(DateTime.now()));
  }

  /// Pushes metrics for yesterday the first time the app opens on a new day.
  Future<void> pushYesterdayIfNewDay() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pushForDate(yesterday);
  }

  /// Convenience for manual entries to overwrite today immediately.
  Future<void> pushToday() async {
    await pushForDate(DateTime.now());
  }

  /// Pushes metrics if we haven't already pushed for the current calendar day.
  Future<void> pushIfNewDay() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final lastKey = _userScopedKey(userId);
    final last = sp.getString(lastKey);
    final todayKey = _dateKey(DateTime.now());
    if (last == todayKey) return;

    await pushYesterdayIfNewDay();
    await backfillMissingIfNeeded();
  }

  /// Backfill missing days in the last 7 days (excluding today) if more than 3 are missing.
  Future<void> backfillMissingIfNeeded() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final start = todayKey.subtract(const Duration(days: 7));
    final end = todayKey.subtract(const Duration(days: 1));

    if (end.isBefore(start)) return;

    final existing = await DailyMetricsApi.fetchRange(
      userId: userId,
      start: start,
      end: end,
    );

    final missing = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (!existing.containsKey(cursor)) {
        missing.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    for (final day in missing) {
      await pushForDate(day);
    }
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
  String _dateKey(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}
