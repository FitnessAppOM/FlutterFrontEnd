import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores diet meals per date locally for offline access.
class DietMealsStorage {
  static const _keyPrefix = "diet_meals_cache";
  static const _lastSyncPrefix = "diet_meals_last_sync";

  static String _dateKey(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  static String _trainingSuffix(int? trainingDayId) {
    if (trainingDayId == null) return "rest";
    return "t$trainingDayId";
  }

  static Future<void> saveMealsForDate(
    DateTime date,
    Map<String, dynamic> data, {
    int? trainingDayId,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final dk = _dateKey(date);
    final suffix = _trainingSuffix(trainingDayId);
    final key = "${_keyPrefix}_u${userId}_${dk}_$suffix";
    final syncKey = "${_lastSyncPrefix}_u${userId}_${dk}_$suffix";

    await sp.setString(key, jsonEncode(data));
    await sp.setString(syncKey, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>?> loadMealsForDate(
    DateTime date, {
    int? trainingDayId,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;

    final sp = await SharedPreferences.getInstance();
    final dk = _dateKey(date);
    final suffix = _trainingSuffix(trainingDayId);
    final key = "${_keyPrefix}_u${userId}_${dk}_$suffix";
    final raw = sp.getString(key);
    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Applies an optimistic offline mutation to a cached day. The callback gets
  /// a deep copy so callers cannot accidentally mutate shared decoded maps.
  static Future<Map<String, dynamic>?> mutateMealsForDate(
    DateTime date,
    Map<String, dynamic> Function(Map<String, dynamic> data) mutation, {
    int? trainingDayId,
  }) async {
    final cached = await loadMealsForDate(date, trainingDayId: trainingDayId);
    if (cached == null) return null;
    final copy = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(cached)) as Map,
    );
    final updated = mutation(copy);
    await saveMealsForDate(date, updated, trainingDayId: trainingDayId);
    return updated;
  }
}
