import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

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

  Future<FitbitActivitySummary?> fetchActivity(DateTime date) async {
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
