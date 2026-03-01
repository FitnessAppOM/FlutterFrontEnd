import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores profile JSON locally for quick rendering on next open.
class ProfileStorage {
  static const _keyPrefix = 'profile_cache';

  static String _userKey(int userId) => '${_keyPrefix}_u$userId';

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userKey(userId), jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_userKey(userId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
