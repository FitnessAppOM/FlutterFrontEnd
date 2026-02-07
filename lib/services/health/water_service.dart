import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';
import '../metrics/daily_metrics_sync.dart';

class WaterService {
  static const _goalKey = "water_goal_liters";
  static const _intakeKey = "water_intake_entries";

  Future<double> getGoal() async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_goalKey);
    return sp.getDouble(key) ?? 2.5;
  }

  Future<void> setGoal(double liters) async {
    final sp = await SharedPreferences.getInstance();
    final key = await _scopedKey(_goalKey);
    await sp.setDouble(key, liters);
  }

  Future<double> getTodayIntake() async {
    final sp = await SharedPreferences.getInstance();
    final intakeKey = await _scopedKey(_intakeKey);
    final raw = sp.getString(intakeKey);
    if (raw == null) return 0;
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final today = DateTime.now();
    final todayKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final val = decoded[todayKey];
    if (val == null) return 0;
    return (val as num).toDouble();
  }

  Future<double> getIntakeForDay(DateTime day) async {
    final sp = await SharedPreferences.getInstance();
    final intakeKey = await _scopedKey(_intakeKey);
    final raw = sp.getString(intakeKey);
    if (raw == null) return 0;
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final dayKey =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final val = decoded[dayKey];
    if (val == null) return 0;
    return (val as num).toDouble();
  }

  Future<void> setTodayIntake(double liters) async {
    final sp = await SharedPreferences.getInstance();
    final intakeKey = await _scopedKey(_intakeKey);
    final raw = sp.getString(intakeKey);
    Map<String, dynamic> decoded = raw == null ? {} : jsonDecode(raw);
    final today = DateTime.now();
    final todayKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    decoded[todayKey] = liters;
    await sp.setString(intakeKey, jsonEncode(decoded));
  }

  Future<void> addToToday(double liters) async {
    await setTodayIntake(liters);
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
