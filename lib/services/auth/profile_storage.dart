import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';

/// Stores profile JSON locally for quick rendering on next open.
class ProfileStorage {
  static const _keyPrefix = 'profile_cache';

  static String _userKey(int userId) => '${_keyPrefix}_u$userId';

  static Future<void> saveProfile(
    Map<String, dynamic> profile, {
    int? userId,
  }) async {
    final effectiveUserId = userId ?? await AccountStorage.getUserId();
    if (effectiveUserId == null || effectiveUserId <= 0) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userKey(effectiveUserId), jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> loadProfile({int? userId}) async {
    final effectiveUserId = userId ?? await AccountStorage.getUserId();
    if (effectiveUserId == null || effectiveUserId <= 0) return null;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_userKey(effectiveUserId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
