import 'package:shared_preferences/shared_preferences.dart';

class AccountStorage {
  static const _kUserId = 'user_id';
  static const _kEmail = 'last_email';
  static const _kName = 'last_name';
  static const _kVerified = 'last_verified';
  static const _kToken = 'auth_token';

  // Save everything after login
  static Future<void> saveUserSession({
    required int userId,
    required String email,
    required String name,
    required bool verified,
    String? token,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kUserId, userId);
    await sp.setString(_kEmail, email);
    await sp.setString(_kName, name);
    await sp.setBool(_kVerified, verified);
    if (token != null) {
      await sp.setString(_kToken, token);
    }
  }

  static Future<int?> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }

  static Future<String?> getEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> getName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kName);
  }

  static Future<bool> isVerified() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kVerified) ?? false;
  }

static Future<void> clearSession() async {
  final sp = await SharedPreferences.getInstance();

  // Only remove session-related values
  await sp.remove(_kUserId);     // logged-in identity
  await sp.remove(_kToken);      // JWT/session token
  await sp.remove(_kVerified);   // verification flag


}

static Future<void> clearSessionOnly() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kToken);
  await sp.remove(_kUserId);
  // Keep email + name + verified → so “Login as…” still works
}

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kEmail);
    await sp.remove(_kName);
    await sp.remove(_kVerified);
    await sp.remove(_kToken);
  }
}
