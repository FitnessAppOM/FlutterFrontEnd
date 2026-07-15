import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'firebase_options.dart';

import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'screens/account_restore_page.dart';
import 'screens/splash/boot_gate.dart';
import 'TaqaUI/styles/taqa_ui_scale.dart';
import 'TaqaUI/styles/taqa_ui_text_scale_guard.dart';
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
import 'services/training/training_service.dart';
import 'core/account_storage.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:io' show Platform;

Future<void> main() {
  if (!kReleaseMode) {
    return _bootstrap();
  }

  return runZoned(
    _bootstrap,
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {}),
  );
}

Future<void> _bootstrap() async {
  final bootWatch = Stopwatch()..start();
  print('[Main] Entry');
  WidgetsFlutterBinding.ensureInitialized();

  // The Android system navigation bar is painted solid white natively in
  // MainActivity.onCreate/onPostResume (window.navigationBarColor). We do that
  // on the native side because Flutter's SystemUiOverlayStyle.light/.dark
  // constants hardcode the nav bar to black and re-apply it on frame changes,
  // which reverted any white we set from here. We still set the status-bar
  // style from Dart, but leave the nav-bar color to the native layer.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Keep larger GIFs in memory to avoid reloads when opening sheets.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 2000;
  // On Android use a smaller cache to reduce memory pressure and OOM kills (e.g. cardio screen). iOS unchanged.
  imageCache.maximumSizeBytes = (Platform.isAndroid ? 120 : 300) << 20;

  print('[Main] Starting app bootstrap');
  Future<T> timed<T>(String stepName, Future<T> Function() task) async {
    final stepWatch = Stopwatch()..start();
    print('[BOOT] $stepName START');
    try {
      final result = await task();
      stepWatch.stop();
      print('[BOOT] $stepName DONE ${stepWatch.elapsedMilliseconds}ms');
      return result;
    } catch (e, st) {
      stepWatch.stop();
      print('[BOOT] $stepName ERROR ${stepWatch.elapsedMilliseconds}ms: $e');
      if (kDebugMode) {
        print(st);
      }
      rethrow;
    }
  }

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
  await timed(
    'Firebase.initializeApp',
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
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
    await timed(
      'TrainingActivityService.stopSession',
      () => TrainingActivityService.stopSession(),
    );
  } catch (_) {
    // ignore
  }

  // Local notifications (permissions + timezone-safe scheduling)
  print('[Main] NotificationService.init() starting');
  try {
    await timed('NotificationService.init', () => NotificationService.init());
    print('[Main] NotificationService.init() done');
  } catch (e, st) {
    // ignore: avoid_print
    print('[Main] NotificationService.init() ERROR: $e\n$st');
  }
  final launchPayload = await timed(
    'NotificationService.getLaunchPayload',
    () => NotificationService.getLaunchPayload(),
  );
  if (launchPayload == NotificationService.dailyJournalPayload) {
    NavigationService.markJournalNotificationPending();
  } else if (launchPayload == NotificationService.dietPayload) {
    NavigationService.markDietNotificationPending();
  } else if (launchPayload == NotificationService.expertAiUpdatesPayload) {
    NavigationService.markExpertAiUpdatesNotificationPending();
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

  await localeController.loadSaved();
  print('[BOOT] Pre-runApp total ${bootWatch.elapsedMilliseconds}ms');
  runApp(WithForegroundTask(child: MyApp(initialPayload: launchPayload)));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    print('[BOOT] First frame ${bootWatch.elapsedMilliseconds}ms');
  });

  // Run non-critical consent/sync work after the first frame so startup is not
  // blocked by permission prompts or health reads.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>(() async {
      // Load env/map token lazily; map screens are not needed at boot.
      try {
        await timed(
          'Deferred dotenv.load',
          () => dotenv.load(fileName: ".env"),
        );
      } catch (e) {
        if (kDebugMode) {
          print('[Main] deferred dotenv load failed: $e');
        }
      }
      try {
        if (dotenv.isInitialized) {
          final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY');
          if (token != null && token.trim().isNotEmpty) {
            MapboxOptions.setAccessToken(token.trim());
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[Main] deferred Mapbox token init failed: $e');
        }
      }

      // Keep push listeners initialized, but don't sync token at startup.
      try {
        await timed(
          'Deferred RemotePushService.init',
          () => RemotePushService.init(),
        );
      } catch (e) {
        print('[Main] RemotePushService deferred init skipped: $e');
      }

      // Scheduling reminders can be deferred to avoid blocking cold start.
      try {
        await timed(
          'Deferred NotificationService.refreshDailyJournalRemindersForCurrentUser',
          () =>
              NotificationService.refreshDailyJournalRemindersForCurrentUser(),
        );
        await timed(
          'Deferred NotificationService.refreshExpertAiUpdatesReminderForCurrentUser',
          () =>
              NotificationService.refreshExpertAiUpdatesReminderForCurrentUser(),
        );
      } catch (e) {
        print('[Main] Notification deferred refresh skipped: $e');
      }

      if (Platform.isIOS) {
        await ConsentManager.requestStartupConsents();
      }
      try {
        await DailyProviderPushService().pushIfAfterOneAmLocal();
      } catch (e) {
        // ignore: avoid_print
        print("DailyMetricsSync daily push skipped: $e");
      }
    });
  });
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
    unawaited(_prefetchTrainingHistorySnapshot());
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
    _maybeRequestAndroidHealthPermission();
    await _prefetchTrainingHistorySnapshot();
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
    await NotificationService.refreshExpertAiUpdatesReminderForCurrentUser();
  }

  void _handleAccountChange() {
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    NotificationService.refreshExpertAiUpdatesReminderForCurrentUser();
    DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
    RemotePushService.init()
        .then((_) => RemotePushService.syncTokenForCurrentUser(force: true))
        .catchError((_) {});
    _maybeRequestAndroidHealthPermission();
    unawaited(_prefetchTrainingHistorySnapshot(force: true));
  }

  Future<void> _prefetchTrainingHistorySnapshot({bool force = false}) async {
    try {
      await TrainingService.prefetchTrainingHistorySnapshot(
        limitDays: 42,
        force: force,
      );
    } catch (_) {
      // Best-effort app-wide preload only.
    }
  }

  Future<void> _maybeRequestAndroidHealthPermission() async {
    if (!Platform.isAndroid ||
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

    return ScreenUtilInit(
      designSize: TaqaUiScale.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Taqa Fitness',
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          builder: (context, appChild) {
            return TaqaUiTextScaleGuard(
              child: appChild ?? const SizedBox.shrink(),
            );
          },
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
