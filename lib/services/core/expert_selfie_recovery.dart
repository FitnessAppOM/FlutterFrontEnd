import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';

/// Only recover photos explicitly selected for this account's coach form.
/// Other image-picker flows must never be interpreted as identity documents.
class ExpertSelfieRecovery {
  static const _ownerKey = 'expert_selfie_picker_owner';
  static const _startedKey = 'expert_selfie_picker_started';
  static const _pathKey = 'expert_selfie_picker_recovered_path';

  static Future<void> begin() async {
    if (!Platform.isAndroid) return;
    final owner = await AccountStorage.getUserId();
    if (owner == null) throw Exception('Please sign in again.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    await prefs.setInt(_ownerKey, owner);
    await prefs.setInt(_startedKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownerKey);
    await prefs.remove(_startedKey);
    await prefs.remove(_pathKey);
  }

  /// Run before any other picker can open after an Android process restart.
  static Future<void> recoverAtStartup() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_ownerKey)) return;
      final owner = await AccountStorage.getUserId();
      final started = prefs.getInt(_startedKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - started;
      if (owner != prefs.getInt(_ownerKey) || age < 0 || age > 1800000) {
        await clear();
        return;
      }
      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty ?? false) {
        await prefs.setString(_pathKey, lost.files!.first.path);
      } else if (!prefs.containsKey(_pathKey)) {
        await clear();
      }
    } catch (_) {
      // Recovery failure must not prevent the rest of the app from starting.
      await clear();
    }
  }

  static Future<XFile?> takeRecoveredPhoto() async {
    if (!Platform.isAndroid) return null;
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getInt(_startedKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - started;
    if (prefs.getInt(_ownerKey) != await AccountStorage.getUserId() ||
        age < 0 ||
        age > 1800000) {
      await clear();
      return null;
    }
    final path = prefs.getString(_pathKey);
    await clear();
    if (path == null || !await File(path).exists()) return null;
    return XFile(path);
  }
}
