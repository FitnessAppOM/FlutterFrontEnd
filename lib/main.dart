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
import 'services/core/notification_service.dart';
import 'screens/daily_journal.dart';
import 'services/core/navigation_service.dart';
import 'services/metrics/daily_metrics_sync.dart';
import 'services/training/exercise_action_queue.dart';
import 'core/account_storage.dart';

void main() async {
  print('[Main] Entry');
  WidgetsFlutterBinding.ensureInitialized();

  print('[Main] Starting app bootstrap');
  // Firebase (REQUIRED for Google Sign-In)
  await Firebase.initializeApp();
  print('[Main] Firebase initialized');

  // Ads (safe to init early)
  await MobileAds.instance.initialize();
  print('[Main] MobileAds initialized');

  // Local notifications (permissions + timezone-safe scheduling)
  print('[Main] NotificationService.init() starting');
  try {
    await NotificationService.init();
    print('[Main] NotificationService.init() done');
  } catch (e, st) {
    // ignore: avoid_print
    print('[Main] NotificationService.init() ERROR: $e\n$st');
  }
  if (kDebugMode) {
    // Fire a few test notifications so you can verify delivery quickly.
    print('[Main] Scheduling debug notifications');
    await NotificationService.scheduleDebugNotificationsEveryTenSeconds(count: 3);
  }
  await NotificationService.refreshDailyJournalRemindersForCurrentUser();
  // Push health metrics for yesterday once per day (on app start) if not already sent today.
  try {
    await DailyMetricsSync().pushIfNewDay();
  } catch (e) {
    // ignore: avoid_print
    print("DailyMetricsSync daily push skipped: $e");
  }
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
  final AppLifecycleListener _lifecycleListener = AppLifecycleListener();

  @override
  void initState() {
    super.initState();
    localeController.addListener(_handleLocaleChange);
    _lifecycleListener.add(_handleLifecycle);
    AccountStorage.accountChange.addListener(_handleAccountChange);
  }

  @override
  void dispose() {
    _lifecycleListener.remove(_handleLifecycle);
    localeController.removeListener(_handleLocaleChange);
    AccountStorage.accountChange.removeListener(_handleAccountChange);
    super.dispose();
  }

  void _handleLocaleChange() {
    if (mounted) setState(() {});
  }

  void _handleLifecycle() async {
    try {
      await DailyMetricsSync().pushIfNewDay();
    } catch (e) {
      // ignore: avoid_print
      print("DailyMetricsSync resume push skipped: $e");
    }
    
    // Sync queued exercise actions when app resumes
    try {
      await ExerciseActionQueue.syncQueue();
    } catch (e) {
      // ignore: avoid_print
      print("ExerciseActionQueue sync skipped: $e");
    }
  }

  void _handleAccountChange() {
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
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

class AppLifecycleListener with WidgetsBindingObserver {
  final List<VoidCallback> _callbacks = [];

  AppLifecycleListener() {
    WidgetsBinding.instance.addObserver(this);
  }

  void add(VoidCallback cb) => _callbacks.add(cb);
  void remove(VoidCallback cb) => _callbacks.remove(cb);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      for (final cb in List<VoidCallback>.from(_callbacks)) {
        cb();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callbacks.clear();
  }
}
