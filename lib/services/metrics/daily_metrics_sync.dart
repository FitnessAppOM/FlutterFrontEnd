import 'dart:async';

import '../../core/account_storage.dart';
import '../diet/calories_service.dart';
import 'daily_metrics_api.dart';
import '../health/sleep_service.dart';
import '../health/steps_service.dart';
import '../health/water_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pulls device/dashboard values for today and pushes them to the backend
/// daily_metrics table for the current signed-in user.
class DailyMetricsSync {
  final StepsService _steps = StepsService();
  final CaloriesService _calories = CaloriesService();
  final SleepService _sleep = SleepService();
  final WaterService _water = WaterService();
  static const _lastPushKey = "daily_metrics_last_push_date";

  Future<void> pushForDate(DateTime day) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      throw Exception("NO_USER");
    }
    final target = DateTime(day.year, day.month, day.day);

    // Fetch in parallel where possible.
    final results = await Future.wait([
      _steps.fetchStepsForDay(target),
      _calories.fetchCaloriesForDay(target),
      _sleep.fetchSleepForDay(target),
      _water.getIntakeForDay(target),
    ]);

    final steps = results[0] as int;
    final calories = results[1] as int;
    final sleepHours = results[2] as double;
    final waterLiters = results[3] as double;

    await DailyMetricsApi.upsert(
      userId: userId,
      entryDate: target,
      steps: steps,
      calories: calories,
      sleepHours: sleepHours,
      waterLiters: waterLiters,
    );

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userScopedKey(userId), _dateKey(DateTime.now()));
  }

  /// Pushes metrics for yesterday the first time the app opens on a new day.
  Future<void> pushYesterdayIfNewDay() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pushForDate(yesterday);
  }

  /// Convenience for manual entries to overwrite today immediately.
  Future<void> pushToday() async {
    await pushForDate(DateTime.now());
  }

  /// Pushes metrics if we haven't already pushed for the current calendar day.
  Future<void> pushIfNewDay() async {
    await pushYesterdayIfNewDay();
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
  String _dateKey(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}
