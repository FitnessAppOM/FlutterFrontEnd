import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class FitbitDailySync {
  static const _lastPushKey = "fitbit_daily_last_push_date";

  Future<void> pushIfNewDay() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return;

    final sp = await SharedPreferences.getInstance();
    final lastKey = _userScopedKey(userId);
    final last = sp.getString(lastKey);
    final todayKey = _dateKey(DateTime.now());
    if (last == todayKey) return;

    // Only proceed if Fitbit is linked.
    final statusUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/status?user_id=$userId");
    final headers = await AccountStorage.getAuthHeaders();
    final statusRes =
        await http.get(statusUrl, headers: headers).timeout(const Duration(seconds: 12));
    if (statusRes.statusCode != 200) return;
    final status = jsonDecode(statusRes.body);
    if (status is! Map || status["linked"] != true) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 7));
    final end = today.subtract(const Duration(days: 1));
    if (end.isBefore(start)) return;

    final startStr = _dateKey(start);
    final endStr = _dateKey(end);
    final rangeUrl = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final rangeRes =
        await http.get(rangeUrl, headers: headers).timeout(const Duration(seconds: 20));
    if (rangeRes.statusCode != 200) return;

    final List<dynamic> rows = jsonDecode(rangeRes.body) as List<dynamic>;
    final existingDates = <String>{};
    for (final row in rows) {
      if (row is Map && row["entry_date"] != null) {
        existingDates.add(row["entry_date"].toString().split("T").first);
      }
    }

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
      await http.get(url, headers: headers).timeout(const Duration(seconds: 25));
    }

    await sp.setString(lastKey, todayKey);
  }

  Future<void> forceBackfillRecent({int days = 7}) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return;

    // Only proceed if Fitbit is linked.
    final statusUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/status?user_id=$userId");
    final headers = await AccountStorage.getAuthHeaders();
    final statusRes =
        await http.get(statusUrl, headers: headers).timeout(const Duration(seconds: 12));
    if (statusRes.statusCode != 200) return;
    final status = jsonDecode(statusRes.body);
    if (status is! Map || status["linked"] != true) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days));
    final end = today.subtract(const Duration(days: 1));
    if (end.isBefore(start)) return;

    final startStr = _dateKey(start);
    final endStr = _dateKey(end);
    final rangeUrl = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final rangeRes =
        await http.get(rangeUrl, headers: headers).timeout(const Duration(seconds: 20));
    if (rangeRes.statusCode != 200) return;

    final List<dynamic> rows = jsonDecode(rangeRes.body) as List<dynamic>;
    final existingDates = <String>{};
    for (final row in rows) {
      if (row is Map && row["entry_date"] != null) {
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
        await http.get(url, headers: headers).timeout(const Duration(seconds: 25));
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  String _dateKey(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  String _userScopedKey(int userId) => "${_lastPushKey}_$userId";
}
