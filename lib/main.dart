import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'theme/app_theme.dart';

// Consents
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'consents/consent_manager.dart';

// Firebase (required for notifications)
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST (required for notifications)
  await Firebase.initializeApp();

  // Show UI immediately
  runApp(const MyApp());

  // Delay consent requests slightly to avoid emulator freeze
  Future.delayed(const Duration(milliseconds: 300), () async {
    await ConsentManager.requestStartupConsents();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAQA Fitness',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      theme: buildDarkTheme(),
      home: WelcomePage(onChangeLanguage: setLocale),
    );
  }
}
