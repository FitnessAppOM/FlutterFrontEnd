import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WaterService {
  static const _goalKey = "water_goal_liters";
  static const _intakeKey = "water_intake_entries";

  Future<double> getGoal() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_goalKey) ?? 2.5;
  }

  Future<void> setGoal(double liters) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_goalKey, liters);
  }

  Future<double> getTodayIntake() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_intakeKey);
    if (raw == null) return 0;
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final today = DateTime.now();
    final key =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final val = decoded[key];
    if (val == null) return 0;
    return (val as num).toDouble();
  }

  Future<void> setTodayIntake(double liters) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_intakeKey);
    Map<String, dynamic> decoded = raw == null ? {} : jsonDecode(raw);
    final today = DateTime.now();
    final key =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    decoded[key] = liters;
    await sp.setString(_intakeKey, jsonEncode(decoded));
  }

  Future<void> addToToday(double liters) async {
    final current = await getTodayIntake();
    await setTodayIntake(current + liters);
  }
}
