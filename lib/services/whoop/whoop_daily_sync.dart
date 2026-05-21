import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/daily_provider_push_service.dart';

class WhoopDailySync {
  static const _lastPushKey = "whoop_daily_last_push_date";
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

      // Always verify WHOOP linked state with backend to avoid stale local flags.
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/whoop/status?user_id=$userId&backfill=1",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (statusRes.statusCode != 200) return;
      final status = jsonDecode(statusRes.body);
      if (status is! Map) return;
      final linked = status["linked"] == true;
      await AccountStorage.setWhoopLinked(linked);
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
          "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$day&persist=1",
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

      // Always verify WHOOP linked state with backend to avoid stale local flags.
      final statusUrl = Uri.parse(
        "${ApiConfig.baseUrl}/whoop/status?user_id=$userId&backfill=1",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final statusRes = await http
          .get(statusUrl, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (statusRes.statusCode != 200) return;
      final status = jsonDecode(statusRes.body);
      if (status is! Map) return;
      final linked = status["linked"] == true;
      await AccountStorage.setWhoopLinked(linked);
      if (!linked) return;

      final start = effectiveToday.subtract(Duration(days: days));
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

      var cursor = end;
      while (!cursor.isBefore(start)) {
        final key = _dateKey(cursor);
        if (!existingDates.contains(key)) {
          final url = Uri.parse(
            "${ApiConfig.baseUrl}/whoop/day?user_id=$userId&date=$key&persist=1",
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
      "${ApiConfig.baseUrl}/whoop/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
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
          _isPersistedWhoopDayRow(row)) {
        existingDates.add(row["entry_date"].toString().split("T").first);
      }
    }
    return existingDates;
  }

  // Keep client-side "existing day" logic aligned with backend backfill logic
  // so partial rows (for example strain-only rows) do not block full persistence.
  bool _isPersistedWhoopDayRow(Map row) {
    if (row["nap_count"] == null) return false;
    final hasSleepStages =
        row["sleep_stage_light_ms"] != null ||
        row["sleep_stage_slow_wave_ms"] != null ||
        row["sleep_stage_rem_ms"] != null;
    final hasSleep =
        hasSleepStages ||
        row["total_sleep_minutes"] != null ||
        row["time_in_bed_minutes"] != null ||
        row["sleep_score"] != null;
    final hasRecovery =
        row["recovery_score"] != null ||
        row["resting_hr"] != null ||
        row["hrv_rmssd"] != null ||
        row["spo2_percent"] != null ||
        row["skin_temp_c"] != null;
    final hasCycle =
        row["strain"] != null ||
        row["avg_hr"] != null ||
        row["max_hr"] != null ||
        row["energy_kj"] != null;
    return hasSleep && hasRecovery && hasCycle;
  }

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
}
