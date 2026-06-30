import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'app_language_code';

class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLangKey);
    if (code != null && code != _locale.languageCode) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_kLangKey, locale.languageCode),
    );
  }
}

final localeController = LocaleController();
