import 'package:flutter/material.dart';

/// Simple locale controller so any screen can trigger a language change.
class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}

final localeController = LocaleController();
