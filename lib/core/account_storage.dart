// lib/core/account_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class AccountStorage {
  static const _kEmail = 'last_email';
  static const _kName  = 'last_name';

  static Future<void> saveLastUser({required String email, String? name}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEmail, email);
    if (name != null) await sp.setString(_kName, name);
  }

  static Future<String?> getLastEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> getLastName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kName);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kEmail);
    await sp.remove(_kName);
  }
}
