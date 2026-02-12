import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class DailyMetricsEntry {
  final DateTime entryDate;
  final double? sleepHours;
  final int? calories;
  final double? waterLiters;
  final int? steps;

  DailyMetricsEntry({
    required this.entryDate,
    this.sleepHours,
    this.calories,
    this.waterLiters,
    this.steps,
  });

  factory DailyMetricsEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        v is DateTime ? v : DateTime.parse(v.toString());
    double? parseDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int? parseInt(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

    return DailyMetricsEntry(
      entryDate: parseDate(json['entry_date']),
      sleepHours: parseDouble(json['sleep_hours']),
      calories: parseInt(json['calories']),
      waterLiters: parseDouble(json['water_liters']),
      steps: parseInt(json['steps']),
    );
  }
}

class DailyMetricsApi {
  static final Map<String, DailyMetricsEntry?> _cache = {};
  static final Map<String, Future<DailyMetricsEntry?>> _inFlight = {};

  static void clearCache() {
    _cache.clear();
  }

  static Future<void> upsert({
    required int userId,
    required DateTime entryDate,
    double? sleepHours,
    int? calories,
    double? waterLiters,
    int? steps,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/daily-metrics/");
    final body = <String, dynamic>{
      "user_id": userId,
      "entry_date": entryDate.toIso8601String().split("T").first,
      if (sleepHours != null) "sleep_hours": sleepHours,
      if (calories != null) "calories": calories,
      if (waterLiters != null) "water_liters": waterLiters,
      if (steps != null) "steps": steps,
    };

    final headers = {"Content-Type": "application/json", ...await AccountStorage.getAuthHeaders()};
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200 || res.statusCode == 409) {
      // 200 inserted, 409 already exists → treat as success for idempotency.
      return;
    }

    throw Exception("Failed to upsert daily metrics: ${res.body}");
  }

  static Future<DailyMetricsEntry?> fetchForDate(int userId, DateTime date) async {
    final dateStr = date.toIso8601String().split("T").first;
    final todayStr = DateTime.now().toIso8601String().split("T").first;
    final cacheKey = "$userId-$dateStr";

    // Serve from cache for past days to avoid repeated HTTP calls.
    if (dateStr != todayStr && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey];
    }

    final url = Uri.parse("${ApiConfig.baseUrl}/daily-metrics/$userId/date/$dateStr");
    final future = http.get(url).then((res) {
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return DailyMetricsEntry.fromJson(data);
      }
      if (res.statusCode == 404) return null;
      throw Exception("Failed to fetch daily metrics: ${res.body}");
    });

    _inFlight[cacheKey] = future;
    try {
      final result = await future;
      if (dateStr != todayStr) {
        _cache[cacheKey] = result;
      }
      return result;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }
}
