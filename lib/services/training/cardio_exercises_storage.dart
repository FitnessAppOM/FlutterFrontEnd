import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

class CardioExercisesStorage {
  static const _key = "cardio_exercises_cache";
  static const _lastSyncKey = "cardio_exercises_last_sync";

  static Future<void> saveList(List<Map<String, dynamic>> items) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final listKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";
    await sp.setString(listKey, jsonEncode(items));
    await sp.setString(syncKey, DateTime.now().toIso8601String());
  }

  static Future<List<Map<String, dynamic>>?> loadList() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final listKey = "${_key}_u$userId";
    final raw = sp.getString(listKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> clearList() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final listKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";
    await sp.remove(listKey);
    await sp.remove(syncKey);
  }
}
