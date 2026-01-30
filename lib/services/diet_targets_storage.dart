import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/account_storage.dart';

/// Stores diet targets locally for offline access
class DietTargetsStorage {
  static const _key = "diet_targets_cache";
  static const _lastSyncKey = "diet_targets_last_sync";

  /// Save diet targets data locally
  static Future<void> saveTargets(Map<String, dynamic> targets) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final targetsKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";

    await sp.setString(targetsKey, jsonEncode(targets));
    await sp.setString(syncKey, DateTime.now().toIso8601String());
  }

  /// Load cached diet targets
  static Future<Map<String, dynamic>?> loadTargets() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;

    final sp = await SharedPreferences.getInstance();
    final targetsKey = "${_key}_u$userId";
    final raw = sp.getString(targetsKey);

    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSync() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;

    final sp = await SharedPreferences.getInstance();
    final syncKey = "${_lastSyncKey}_u$userId";
    final raw = sp.getString(syncKey);

    if (raw == null) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Clear cached targets
  static Future<void> clearTargets() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final targetsKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";

    await sp.remove(targetsKey);
    await sp.remove(syncKey);
  }
}

