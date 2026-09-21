import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingReferralCodeStore {
  PendingReferralCodeStore._();

  static const String storageKey = 'pending_referral_code';
  static final ValueNotifier<String?> code = ValueNotifier<String?>(null);

  static String? normalize(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    if (value.length != 18 ||
        !value.startsWith('TQ') ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static Future<void> remember(String raw) async {
    final value = normalize(raw);
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
    code.value = value;
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = normalize(prefs.getString(storageKey));
    if (value == null) {
      await prefs.remove(storageKey);
    }
    code.value = value;
    return value;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    code.value = null;
  }
}
