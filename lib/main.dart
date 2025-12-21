import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'theme/app_theme.dart';
import 'core/locale_controller.dart';
import 'consents/consent_manager.dart';
import 'services/notification_service.dart';
import 'screens/daily_journal.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (REQUIRED for Google Sign-In)
  await Firebase.initializeApp();

  // Ads (safe to init early)
  await MobileAds.instance.initialize();

  // Local notifications (permissions + timezone-safe scheduling)
  await NotificationService.init();
  if (kDebugMode) {
    // Fire a few test notifications so you can verify delivery quickly.
    await NotificationService.scheduleDebugNotificationsEveryTenSeconds(count: 3);
  }
  await NotificationService.scheduleDailyJournalReminder();
  final launchPayload = await NotificationService.getLaunchPayload();
  NavigationService.launchedFromNotificationPayload =
      launchPayload == NotificationService.dailyJournalPayload;

  runApp(MyApp(initialPayload: launchPayload));


  //  Delay consent request to avoid iOS freeze
  Future.delayed(
    const Duration(milliseconds: 300),
        () async => await ConsentManager.requestStartupConsents(),
  );
}

class MyApp extends StatefulWidget {
  final String? initialPayload;

  const MyApp({super.key, this.initialPayload});

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
    final initialRoute =
        widget.initialPayload == NotificationService.dailyJournalPayload
            ? '/daily-journal'
            : '/';

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
      navigatorKey: NavigationService.navigatorKey,
      initialRoute: initialRoute,
      routes: {
        '/': (_) => WelcomePage(onChangeLanguage: localeController.setLocale),
        '/daily-journal': (_) => const DailyJournalPage(),
      },
    );
  }
}
