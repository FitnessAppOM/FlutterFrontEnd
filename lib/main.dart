import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'screens/account_restore_page.dart';
import 'screens/splash/boot_gate.dart';
import 'theme/app_theme.dart';
import 'core/locale_controller.dart';
import 'consents/consent_manager.dart';
import 'services/core/notification_service.dart';
import 'services/core/remote_push_service.dart';
import 'screens/daily_journal.dart';
import 'services/core/navigation_service.dart';
import 'services/core/daily_provider_push_service.dart';
import 'services/training/exercise_action_queue.dart';
import 'services/training/cardio_session_queue.dart';
import 'services/training/training_activity_service.dart';
import 'core/account_storage.dart';
import 'services/screenings/screening_prompt_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:io' show Platform;

void main() async {
  print('[Main] Entry');
  WidgetsFlutterBinding.ensureInitialized();
  // Keep larger GIFs in memory to avoid reloads when opening sheets.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 2000;
  // On Android use a smaller cache to reduce memory pressure and OOM kills (e.g. cardio screen). iOS unchanged.
  imageCache.maximumSizeBytes = (Platform.isAndroid ? 120 : 300) << 20;

  print('[Main] Starting app bootstrap');
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'training_session',
      channelName: 'Training Session',
      channelDescription: 'Ongoing training session timer.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      enableVibration: false,
      playSound: false,
    ),
    iosNotificationOptions: IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // Firebase (REQUIRED for Google Sign-In)
  await Firebase.initializeApp();
  try {
    final opts = Firebase.app().options;
    final pkg = await PackageInfo.fromPlatform();
    print(
      '[Main] Bundle: package=${pkg.packageName} version=${pkg.version}+${pkg.buildNumber}',
    );
    print(
      '[Main] Firebase options: '
      'projectId=${opts.projectId} appId=${opts.appId} '
      'iosBundleId=${opts.iosBundleId} iosClientId=${opts.iosClientId} '
      'apiKey=${opts.apiKey} messagingSenderId=${opts.messagingSenderId} '
      'authDomain=${opts.authDomain} storageBucket=${opts.storageBucket}',
    );
  } catch (e) {
    print('[Main] Firebase initialized (options unavailable): $e');
  }

  // Cancel any stale training/cardio session on cold start.
  try {
    await TrainingActivityService.stopSession();
  } catch (_) {
    // ignore
  }

  // Load env (Mapbox token, etc.)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    if (kDebugMode) {
      print('[Main] dotenv load failed: $e');
    }
  }

  // Configure Mapbox access token if present.
  try {
    if (dotenv.isInitialized) {
      final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY');
      if (token != null && token.trim().isNotEmpty) {
        MapboxOptions.setAccessToken(token.trim());
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('[Main] Mapbox token init failed: $e');
    }
  }

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
  try {
    await RemotePushService.init();
    await RemotePushService.syncTokenForCurrentUser();
  } catch (e) {
    // ignore: avoid_print
    print('[Main] RemotePushService init/sync skipped: $e');
  }
  // // Fire test notifications immediately so you can verify delivery quickly.
  // print('[Main] Showing debug notifications');
  // await NotificationService.showDebugJournalAndDietNow();
  // Submit today's burn BEFORE scheduling notifications so the 9pm diet
  // check-in body reflects the surplus-adjusted target, not the base target.
  try {
    await DailyProviderPushService().pushIfAfterOneAmLocal();
  } catch (e) {
    // ignore: avoid_print
    print("DailyMetricsSync daily push skipped: $e");
  }
  await NotificationService.refreshDailyJournalRemindersForCurrentUser();
  final launchPayload = await NotificationService.getLaunchPayload();
  if (launchPayload == NotificationService.dailyJournalPayload) {
    NavigationService.markJournalNotificationPending();
  } else if (launchPayload == NotificationService.dietPayload) {
    NavigationService.markDietNotificationPending();
  }

  // When backend returns 401, clear session and send user to welcome (login).
  AccountStorage.onUnauthorized = () {
    NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            WelcomePage(onChangeLanguage: localeController.setLocale),
      ),
      (_) => false,
    );
  };
  AccountStorage.onDeactivated = (payload) {
    Future<void>(() async {
      final email = await AccountStorage.getEmail();
      NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AccountRestorePage(
            initialPayload: payload,
            prefilledEmail: email,
          ),
        ),
        (_) => false,
      );
    });
  };

  runApp(WithForegroundTask(child: MyApp(initialPayload: launchPayload)));

  //  Delay consent request to avoid iOS freeze
  if (Platform.isIOS) {
    Future.delayed(
      const Duration(milliseconds: 300),
      () async => await ConsentManager.requestStartupConsents(),
    );
  }
}

class MyApp extends StatefulWidget {
  final String? initialPayload;

  const MyApp({super.key, this.initialPayload});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLifecycleListener _lifecycleListener = AppLifecycleListener();
  bool _androidHealthPermissionInFlight = false;
  bool _androidHealthPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    localeController.addListener(_handleLocaleChange);
    _lifecycleListener.add(_handleLifecycle);
    AccountStorage.accountChange.addListener(_handleAccountChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRequestAndroidHealthPermission();
    });
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
    RemotePushService.syncTokenForCurrentUser().catchError((_) {});
    _maybeRequestAndroidHealthPermission();
    try {
      await DailyProviderPushService().pushIfAfterOneAmLocal();
    } catch (e) {
      // ignore: avoid_print
      print("DailyMetricsSync resume push skipped: $e");
    }

    // Sync queued exercise actions when app resumes
    try {
      await ExerciseActionQueue.syncQueue();
      await CardioSessionQueue.syncQueue();
    } catch (e) {
      // ignore: avoid_print
      print("ExerciseActionQueue sync skipped: $e");
    }
    await NotificationService.refreshDailyJournalRemindersForCurrentUser();
  }

  void _handleAccountChange() {
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
    RemotePushService.syncTokenForCurrentUser(force: true).catchError((_) {});
    _maybeRequestAndroidHealthPermission();
  }

  Future<void> _maybeRequestAndroidHealthPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS) ||
        _androidHealthPermissionGranted ||
        _androidHealthPermissionInFlight) {
      return;
    }
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    _androidHealthPermissionInFlight = true;
    try {
      // Wait a beat so startup/login transitions settle before launching
      // Health Connect's permission activity.
      await Future.delayed(const Duration(milliseconds: 600));
      final granted = await ConsentManager.requestUnifiedHealthPermissionsJIT();
      if (granted) {
        _androidHealthPermissionGranted = true;
      }
    } finally {
      _androidHealthPermissionInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute =
        widget.initialPayload == NotificationService.dailyJournalPayload
        ? '/daily-journal'
        : '/';

    return MaterialApp(
      title: 'Taqa Fitness',
      debugShowCheckedModeBanner: false,
      locale: localeController.locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: buildDarkTheme(),
      navigatorKey: NavigationService.navigatorKey,
      initialRoute: initialRoute,
      routes: {
        '/': (_) => const BootGate(),
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

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callbacks.clear();
  }
}
