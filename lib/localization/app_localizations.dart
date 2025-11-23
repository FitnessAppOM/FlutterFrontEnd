import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Access localization anywhere in the app
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // All translations go here
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome_tagline': 'Log your workouts easily, all in one place.',
      'saved_accounts': 'saved accounts',
      'login': 'Log in',
      'login_with_another': 'Log in using another account',
      'login_as': 'Log in as',
      'new_to_taqa': 'New to TAQA? ',
      'signup': 'Sign up',
    },

    'ar': {
      'welcome_tagline': 'سجّل تمارينك بسهولة، في مكان واحد.',
      'saved_accounts': 'الحسابات المحفوظة',
      'login': 'تسجيل الدخول',
      'login_with_another': 'تسجيل الدخول باستخدام حساب آخر',
      'login_as': 'تسجيل الدخول باسم',
      'new_to_taqa': 'هل أنت جديد في TAQA؟ ',
      'signup': 'إنشاء حساب',
    }
  };

  // Function to get the translated string
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

// The delegate that tells Flutter how to load our translations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate old) => false;
}
