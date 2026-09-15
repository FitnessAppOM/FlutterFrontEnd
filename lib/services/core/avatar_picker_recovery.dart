import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';

/// Recovers an avatar selected while Android recreated the app process.
///
/// The owner marker prevents a result from another account or another picker
/// flow from being uploaded as this user's avatar.
class AvatarPickerRecovery {
  static const _ownerKey = 'avatar_picker_owner';
  static const _startedKey = 'avatar_picker_started';
  static const _pathKey = 'avatar_picker_recovered_path';
  static const _maxAge = Duration(minutes: 30);

  static Future<void> begin() async {
    if (!Platform.isAndroid) return;
    final owner = await AccountStorage.getUserId();
    if (owner == null) throw Exception('Please sign in again.');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    await prefs.setInt(_ownerKey, owner);
    await prefs.setInt(_startedKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> remember(String path) async {
    if (!Platform.isAndroid || path.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_ownerKey)) return;
    await prefs.setString(_pathKey, path);
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownerKey);
    await prefs.remove(_startedKey);
    await prefs.remove(_pathKey);
  }

  /// Must run at startup before a new image picker is opened.
  static Future<void> recoverAtStartup() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_ownerKey)) return;
      if (!await _belongsToCurrentAccount(prefs)) {
        await clear();
        return;
      }

      final rememberedPath = prefs.getString(_pathKey);
      if (rememberedPath != null && await File(rememberedPath).exists()) {
        return;
      }

      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty ?? false) {
        await prefs.setString(_pathKey, lost.files!.first.path);
      } else {
        await clear();
      }
    } catch (_) {
      // Picker recovery must never prevent the app from starting.
      await clear();
    }
  }

  static Future<XFile?> pendingPhoto() async {
    if (!Platform.isAndroid) return null;
    final prefs = await SharedPreferences.getInstance();
    if (!await _belongsToCurrentAccount(prefs)) {
      await clear();
      return null;
    }

    final path = prefs.getString(_pathKey);
    if (path == null || !await File(path).exists()) {
      await clear();
      return null;
    }
    return XFile(path);
  }

  static Future<bool> _belongsToCurrentAccount(SharedPreferences prefs) async {
    final started = prefs.getInt(_startedKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - started;
    return prefs.getInt(_ownerKey) == await AccountStorage.getUserId() &&
        age >= 0 &&
        age <= _maxAge.inMilliseconds;
  }
}
