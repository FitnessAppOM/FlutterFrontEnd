// lib/core/account_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class AccountStorage {
  static const _kEmail    = 'last_email';
  static const _kName     = 'last_name';
  static const _kVerified = 'last_verified';   // NEW
  static const _kToken    = 'auth_token';      // optional

  /// Save minimal "last user" (no token). Use verified=false for fresh signups.
  static Future<void> saveLastUser({
    required String email,
    String? name,
    bool verified = false, // NEW: default to not verified
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEmail, email);
    if (name != null) await sp.setString(_kName, name);
    await sp.setBool(_kVerified, verified);
  }

  /// Full session save (e.g., after successful login or verify).
  static Future<void> saveUserSession({
    required String email,
    required String name,
    required bool verified,
    String? token, // optional JWT
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEmail, email);
    await sp.setString(_kName, name);
    await sp.setBool(_kVerified, verified);
    if (token != null) await sp.setString(_kToken, token);
  }

  static Future<String?> getLastEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> getLastName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kName);
  }

  static Future<bool> getLastVerified() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kVerified) ?? false; // default false for old installs
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<void> setVerified(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kVerified, value);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kEmail);
    await sp.remove(_kName);
    await sp.remove(_kVerified);
    await sp.remove(_kToken);
  }
}
