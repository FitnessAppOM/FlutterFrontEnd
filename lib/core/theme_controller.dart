import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaqaThemePreference { system, light, dark }

/// Owns the app appearance preference and persists it between launches.
class TaqaThemeController extends ChangeNotifier {
  static const _preferenceKey = 'taqa_theme_preference_v1';

  // Keep the existing light appearance for users who have not chosen a mode.
  TaqaThemePreference _preference = TaqaThemePreference.light;

  TaqaThemePreference get preference => _preference;

  ThemeMode get themeMode {
    return switch (_preference) {
      TaqaThemePreference.system => ThemeMode.system,
      TaqaThemePreference.light => ThemeMode.light,
      TaqaThemePreference.dark => ThemeMode.dark,
    };
  }

  Future<void> loadSaved() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    _preference = TaqaThemePreference.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => TaqaThemePreference.light,
    );
  }

  Future<void> setPreference(TaqaThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, preference.name);
  }
}

final themeController = TaqaThemeController();
