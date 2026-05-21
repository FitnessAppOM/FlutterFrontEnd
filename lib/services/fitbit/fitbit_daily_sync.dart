import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/daily_provider_push_service.dart';

class FitbitDailySync {
  static const _lastPushKey = "fitbit_daily_last_push_date";
  static bool _syncInFlight = false;

  Future<void> pushIfNewDay() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) return;
      final effectiveToday = DailyProviderPushService.effectiveLocalDay();

      final sp = await SharedPreferences.getInstance();
      final lastKey = _userScopedKey(userId);
      final todayKey = _dateKey(effectiveToday);

      // Always verify Fitbit linked state with backend to avoid stale local flags.
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (statusRes.statusCode != 200) return;
      final status = jsonDecode(statusRes.body);
      if (status is! Map) return;
      final linked = status["linked"] == true;
      await AccountStorage.setFitbitLinked(linked);
      if (!linked) return;

      final start = effectiveToday.subtract(const Duration(days: 7));
      final end = effectiveToday;
      if (end.isBefore(start)) return;

      final startStr = _dateKey(start);
      final endStr = _dateKey(end);
      final existingDates = await _fetchExistingDates(
        userId: userId,
        startStr: startStr,
        endStr: endStr,
        headers: headers,
      );
      if (existingDates == null) return;

      final missingDates = <String>[];
      var cursor = start;
      while (!cursor.isAfter(end)) {
        final key = _dateKey(cursor);
        if (!existingDates.contains(key)) {
          missingDates.add(key);
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      for (final day in missingDates) {
        final url = Uri.parse(
          "${ApiConfig.baseUrl}/fitbit/day?user_id=$userId&date=$day&persist=1",
        );
        await http
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 25));
      }

      if (missingDates.isEmpty) {
        await sp.setString(lastKey, todayKey);
        return;
      }

      final refreshedDates = await _fetchExistingDates(
        userId: userId,
        startStr: startStr,
        endStr: endStr,
        headers: headers,
      );
      if (refreshedDates == null) return;

      final stillMissing = missingDates.where(
        (day) => !refreshedDates.contains(day),
      );
      if (stillMissing.isEmpty) {
        await sp.setString(lastKey, todayKey);
      }
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> forceBackfillRecent({int days = 7}) async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId == 0) return;
      final effectiveToday = DailyProviderPushService.effectiveLocalDay();

      // Always verify Fitbit linked state with backend to avoid stale local flags.
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (statusRes.statusCode != 200) return;
      final status = jsonDecode(statusRes.body);
      if (status is! Map) return;
      final linked = status["linked"] == true;
      await AccountStorage.setFitbitLinked(linked);
      if (!linked) return;

      final start = effectiveToday.subtract(Duration(days: days));
      final end = effectiveToday;
      if (end.isBefore(start)) return;

      final startStr = _dateKey(start);
      final endStr = _dateKey(end);
      final rangeUrl = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
      );
      final rangeRes = await http
          .get(rangeUrl, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (rangeRes.statusCode != 200) return;

      final List<dynamic> rows = jsonDecode(rangeRes.body) as List<dynamic>;
      final existingDates = <String>{};
      for (final row in rows) {
        if (row is Map &&
            row["entry_date"] != null &&
            _isPersistedFitbitDayRow(row)) {
          existingDates.add(row["entry_date"].toString().split("T").first);
        }
      }

      var cursor = end;
      while (!cursor.isBefore(start)) {
        final key = _dateKey(cursor);
        if (!existingDates.contains(key)) {
          final url = Uri.parse(
            "${ApiConfig.baseUrl}/fitbit/day?user_id=$userId&date=$key&persist=1",
          );
          await http
              .get(url, headers: headers)
              .timeout(const Duration(seconds: 25));
        }
        cursor = cursor.subtract(const Duration(days: 1));
      }
    } finally {
      _syncInFlight = false;
    }
  }

  String _dateKey(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  Future<Set<String>?> _fetchExistingDates({
    required int userId,
    required String startStr,
    required String endStr,
    required Map<String, String> headers,
  }) async {
    final rangeUrl = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final rangeRes = await http
        .get(rangeUrl, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (rangeRes.statusCode != 200) return null;

    final decoded = jsonDecode(rangeRes.body);
    if (decoded is! List) return null;
    final existingDates = <String>{};
    for (final row in decoded) {
      if (row is Map &&
          row["entry_date"] != null &&
          _isPersistedFitbitDayRow(row)) {
        existingDates.add(row["entry_date"].toString().split("T").first);
      }
    }
    return existingDates;
  }

  bool _isPositiveNum(dynamic value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    final parsed = double.tryParse(value.toString());
    return parsed != null && parsed > 0;
  }

  bool _hasNonEmptyStructured(dynamic value) {
    if (value == null) return false;
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    final text = value.toString().trim();
    if (text.isEmpty) return false;
    if (text == '{}' || text == '[]' || text.toLowerCase() == 'null') {
      return false;
    }
    return true;
  }

  bool _isPersistedFitbitDayRow(Map row) {
    final hasActivity =
        _isPositiveNum(row["steps"]) ||
        _isPositiveNum(row["distance_km"]) ||
        _isPositiveNum(row["calories_out"]) ||
        _isPositiveNum(row["floors"]) ||
        _isPositiveNum(row["active_minutes"]);

    final hasSleep =
        _isPositiveNum(row["sleep_minutes_asleep"]) ||
        _isPositiveNum(row["sleep_time_in_bed"]) ||
        _isPositiveNum(row["sleep_efficiency"]) ||
        _hasNonEmptyStructured(row["sleep_stages_json"]);

    final hasRecovery =
        _isPositiveNum(row["resting_hr"]) ||
        _isPositiveNum(row["hrv_daily_rmssd"]) ||
        _isPositiveNum(row["hrv_deep_rmssd"]) ||
        _hasNonEmptyStructured(row["heart_zones"]);

    final hasVitals =
        _isPositiveNum(row["cardio_vo2max"]) ||
        _isPositiveNum(row["spo2_avg"]) ||
        _isPositiveNum(row["spo2_min"]) ||
        _isPositiveNum(row["spo2_max"]) ||
        _isPositiveNum(row["skin_temp_c"]) ||
        _isPositiveNum(row["breathing_rate"]) ||
        _isPositiveNum(row["ecg_avg_hr"]) ||
        _hasNonEmptyStructured(row["ecg_summary"]);

    final hasBody = _isPositiveNum(row["weight_kg"]);
    final hasScores =
        _isPositiveNum(row["sleep_score"]) ||
        _isPositiveNum(row["readiness_score"]) ||
        _isPositiveNum(row["stress_management_score"]);
    return hasActivity ||
        hasSleep ||
        hasRecovery ||
        hasVitals ||
        hasScores ||
        hasBody;
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
}
