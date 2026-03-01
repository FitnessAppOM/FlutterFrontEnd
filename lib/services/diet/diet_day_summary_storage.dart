import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores diet day summary per date locally for offline access.
class DietDaySummaryStorage {
  static const _keyPrefix = "diet_day_summary_cache";

  static String _dateKey(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  static Future<void> saveSummaryForDate(
    DateTime date,
    Map<String, dynamic> data,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final dk = _dateKey(date);
    final key = "${_keyPrefix}_u${userId}_${dk}";

    await sp.setString(key, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadSummaryForDate(
    DateTime date,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;

    final sp = await SharedPreferences.getInstance();
    final dk = _dateKey(date);
    final key = "${_keyPrefix}_u${userId}_${dk}";
    final raw = sp.getString(key);
    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
