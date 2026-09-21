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
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'firebase_options.dart';

import 'localization/app_localizations.dart';
import 'screens/welcome.dart';
import 'screens/account_restore_page.dart';
import 'screens/splash/boot_gate.dart';
import 'TaqaUI/styles/taqa_ui_scale.dart';
import 'TaqaUI/styles/taqa_ui_text_scale_guard.dart';
import 'TaqaUI/components/taqa_ios_update_banner.dart';
import 'theme/app_theme.dart';
import 'core/locale_controller.dart';
import 'consents/consent_manager.dart';
import 'services/core/notification_service.dart';
import 'services/core/remote_push_service.dart';
import 'screens/daily_journal.dart';
import 'services/core/navigation_service.dart';
import 'services/core/daily_provider_push_service.dart';
import 'services/core/network_status_service.dart';
import 'services/core/expert_selfie_recovery.dart';
import 'services/core/avatar_picker_recovery.dart';
import 'services/core/offline_sync_coordinator.dart';
import 'services/core/app_release_policy_service.dart';
import 'services/core/play_in_app_update_service.dart';
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

void _configureTrainingForegroundTask() {
  final t = AppLocalizations(localeController.locale);
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      // Android notification-channel importance is immutable after creation.
      // v3 was HIGH and Samsung surfaced every timer update as a heads-up
      // alert, so use a fresh default/silent channel for ongoing workouts.
      channelId: 'training_session_v4',
      channelName: t.translate('training_notification_channel_name'),
      channelDescription: t.translate(
        'training_notification_channel_description',
      ),
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      enableVibration: false,
      playSound: false,
      showWhen: true,
      isSticky: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
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
}

Future<void> _bootstrap() async {
  final bootWatch = Stopwatch()..start();
  print('[Main] Entry');
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    final imagePicker = ImagePickerPlatform.instance;
    if (imagePicker is ImagePickerAndroid) {
      // Keep gallery actions inside Android's image-only Photo Picker instead
      // of the document browser used by ACTION_GET_CONTENT.
      imagePicker.useAndroidPhotoPicker = true;
    }
  }
  await ExpertSelfieRecovery.recoverAtStartup();
  await AvatarPickerRecovery.recoverAtStartup();
  await localeController.loadSaved();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

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

  _configureTrainingForegroundTask();

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
  AccountStorage.onDeactivated = (payload) async {
    final responseEmail = payload['email']?.toString().trim();
    final storedEmail = await AccountStorage.getEmail();
    final email = responseEmail != null && responseEmail.isNotEmpty
        ? responseEmail
        : storedEmail;
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            AccountRestorePage(initialPayload: payload, prefilledEmail: email),
      ),
      (_) => false,
    );
  };

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

      // Keep startup validation uncontended. Network sync and permission work
      // can begin once the first authenticated route has resolved its gates.
      await NavigationService.waitUntilStartupReady();

      // Initialize push listeners and let RemotePushService own the single
      // startup token registration.
      try {
        await timed(
          'Deferred RemotePushService.init',
          () => RemotePushService.init(),
        );
      } catch (e) {
        print('[Main] RemotePushService deferred init skipped: $e');
      }

      final hasSubscriptionAccess =
          await AccountStorage.hasVerifiedSubscriptionAccess();
      if (!hasSubscriptionAccess) return;

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
    unawaited(_initializeOfflineServices());
    unawaited(_runPostStartupWork());
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
    _configureTrainingForegroundTask();
    unawaited(TrainingActivityService.refreshLocalization());
    unawaited(NotificationService.refreshLocalization());
    unawaited(RemotePushService.syncTokenForCurrentUser(force: true));
    unawaited(
      AppReleasePolicyService.instance.checkForUpdate(
        languageCode: localeController.locale.languageCode,
      ),
    );
  }

  Future<void> _initializeOfflineServices() async {
    await NetworkStatusService.instance.initialize();
    await OfflineSyncCoordinator.instance.initialize();
  }

  void _handleLifecycle() async {
    await NetworkStatusService.instance.checkNow();
    await AppReleasePolicyService.instance.initialize(
      languageCode: localeController.locale.languageCode,
    );
    await PlayInAppUpdateService.instance.initialize();
    unawaited(PlayInAppUpdateService.instance.checkForUpdate());
    if (!await AccountStorage.hasVerifiedSubscriptionAccess()) {
      await NotificationService.syncForSubscriptionAccess(active: false);
      return;
    }
    _maybeRequestAndroidHealthPermission();
    await _prefetchTrainingHistorySnapshot();
    try {
      await DailyProviderPushService().pushIfAfterOneAmLocal();
    } catch (e) {
      // ignore: avoid_print
      print("DailyMetricsSync resume push skipped: $e");
    }

    // Sync every registered offline queue when app resumes.
    try {
      await OfflineSyncCoordinator.instance.syncNow();
    } catch (e) {
      // ignore: avoid_print
      print("Offline queue sync skipped: $e");
    }
    await NotificationService.refreshDailyJournalRemindersForCurrentUser();
    await NotificationService.refreshExpertAiUpdatesReminderForCurrentUser();
  }

  void _handleAccountChange() {
    unawaited(_handleAccountChangeAfterStartup());
  }

  Future<void> _handleAccountChangeAfterStartup() async {
    await NavigationService.waitUntilStartupReady();
    await RemotePushService.init();
    final hasSubscriptionAccess =
        await AccountStorage.hasVerifiedSubscriptionAccess();
    if (!hasSubscriptionAccess) {
      await NotificationService.syncForSubscriptionAccess(active: false);
      await RemotePushService.unregisterTokenForCurrentUser();
      return;
    }
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
    NotificationService.refreshExpertAiUpdatesReminderForCurrentUser();
    DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
    RemotePushService.syncTokenForCurrentUser(force: true).catchError((_) {});
    _maybeRequestAndroidHealthPermission();
    unawaited(_prefetchTrainingHistorySnapshot(force: true));
    await OfflineSyncCoordinator.instance.refreshPendingCount();
    if (NetworkStatusService.instance.isOnline &&
        OfflineSyncCoordinator.instance.pendingCount > 0) {
      unawaited(OfflineSyncCoordinator.instance.syncNow(showSuccess: true));
    }
  }

  Future<void> _runPostStartupWork() async {
    unawaited(
      AppReleasePolicyService.instance.initialize(
        languageCode: localeController.locale.languageCode,
      ),
    );
    await NavigationService.waitUntilStartupReady();
    if (!mounted) return;
    unawaited(PlayInAppUpdateService.instance.initialize());
    if (!await AccountStorage.hasVerifiedSubscriptionAccess()) return;
    unawaited(_prefetchTrainingHistorySnapshot());
    unawaited(_maybeRequestAndroidHealthPermission());
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
    if (!await AccountStorage.hasVerifiedSubscriptionAccess()) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    _androidHealthPermissionInFlight = true;
    try {
      // Wait a beat so startup/login transitions settle before launching
      // Health Connect's permission activity.
      await Future.delayed(const Duration(milliseconds: 600));
      await ConsentManager.requestActivityRecognitionAndroid();
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
              child: Stack(
                children: [
                  appChild ?? const SizedBox.shrink(),
                  const TaqaRequiredUpdateOverlay(),
                ],
              ),
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
