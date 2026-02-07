import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores training programs locally for offline access
class TrainingProgramStorage {
  static const _key = "training_program_cache";
  static const _lastSyncKey = "training_program_last_sync";

  /// Save program data locally
  static Future<void> saveProgram(Map<String, dynamic> program) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final programKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";

    // Save program data
    await sp.setString(programKey, jsonEncode(program));
    
    // Save sync timestamp
    await sp.setString(syncKey, DateTime.now().toIso8601String());
  }

  /// Load cached program
  static Future<Map<String, dynamic>?> loadProgram() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;

    final sp = await SharedPreferences.getInstance();
    final programKey = "${_key}_u$userId";
    final raw = sp.getString(programKey);

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

  /// Clear cached program
  static Future<void> clearProgram() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final programKey = "${_key}_u$userId";
    final syncKey = "${_lastSyncKey}_u$userId";

    await sp.remove(programKey);
    await sp.remove(syncKey);
  }
}
