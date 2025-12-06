import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'theme/app_theme.dart';
import 'core/locale_controller.dart';

// Consents
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'consents/consent_manager.dart';

// REMOVE Firebase (you have no configuration yet)
// import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Ads only (safe)
  await MobileAds.instance.initialize();

  // Show the UI immediately
  runApp(const MyApp());

  // Request startup consents (delay avoids iOS freeze)
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
    // Rebuild MaterialApp whenever the locale changes.
    localeController.addListener(_handleLocaleChange);
  }

  @override
  void dispose() {
    localeController.removeListener(_handleLocaleChange);
    super.dispose();
  }

  void _handleLocaleChange() {
    if (mounted) {
      setState(() {});
    }
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
