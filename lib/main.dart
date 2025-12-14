import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'theme/app_theme.dart';
import 'core/locale_controller.dart';
import 'consents/consent_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (REQUIRED for Google Sign-In)
  await Firebase.initializeApp();

  // Ads (safe to init early)
  await MobileAds.instance.initialize();

  runApp(const MyApp());

  //  Delay consent request to avoid iOS freeze
  Future.delayed(
    const Duration(milliseconds: 300),
        () async => await ConsentManager.requestStartupConsents(),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    localeController.addListener(_handleLocaleChange);
  }

  @override
  void dispose() {
    localeController.removeListener(_handleLocaleChange);
    super.dispose();
  }

  void _handleLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAQA Fitness',
      debugShowCheckedModeBanner: false,
      locale: localeController.locale,
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
      home: WelcomePage(onChangeLanguage: localeController.setLocale),
    );
  }
}
