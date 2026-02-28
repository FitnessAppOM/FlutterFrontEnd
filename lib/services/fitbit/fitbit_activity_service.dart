import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'fitbit_db_service.dart';

class FitbitActivitySummary {
  final int? steps;
  final double? distance;
  final int? calories;
  final int? floors;
  final int? activeMinutes;

  final int? goalSteps;
  final double? goalDistance;
  final int? goalCalories;
  final int? goalFloors;
  final int? goalActiveMinutes;

  const FitbitActivitySummary({
    required this.steps,
    required this.distance,
    required this.calories,
    required this.floors,
    required this.activeMinutes,
    required this.goalSteps,
    required this.goalDistance,
    required this.goalCalories,
    required this.goalFloors,
    required this.goalActiveMinutes,
  });
}

class FitbitActivityService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<FitbitActivitySummary?> fetchActivity(DateTime date) async {
    if (!_isToday(date)) {
      final row = await FitbitDailyMetricsDbService().fetchRow(date);
      if (row == null) return null;
      int? _int(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      double? _double(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      return FitbitActivitySummary(
        steps: _int(row["steps"]),
        distance: _double(row["distance_km"]),
        calories: _int(row["calories_out"]),
        floors: _int(row["floors"]),
        activeMinutes: _int(row["active_minutes"]),
        goalSteps: _int(row["steps_goal"]),
        goalDistance: _double(row["distance_goal_km"]),
        goalCalories: _int(row["calories_goal"]),
        goalFloors: _int(row["floors_goal"]),
        goalActiveMinutes: _int(row["active_minutes_goal"]),
      );
    }
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final url = Uri.parse("${ApiConfig.baseUrl}/fitbit/activity?user_id=$userId&date=$dateStr");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception("Failed to load Fitbit activity: ${res.body}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final summary = (data["summary"] ?? {}) as Map<String, dynamic>;
    final goals = (data["goals"] ?? {}) as Map<String, dynamic>;

    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return FitbitActivitySummary(
      steps: _int(summary["steps"]),
      distance: _double(summary["distance"]),
      calories: _int(summary["calories"]),
      floors: _int(summary["floors"]),
      activeMinutes: _int(summary["active_minutes"]),
      goalSteps: _int(goals["steps"]),
      goalDistance: _double(goals["distance"]),
      goalCalories: _int(goals["calories"]),
      goalFloors: _int(goals["floors"]),
      goalActiveMinutes: _int(goals["active_minutes"]),
    );
  }
}
