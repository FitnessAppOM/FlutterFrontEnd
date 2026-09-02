import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ATT (iOS)
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// Notifications
import 'package:firebase_messaging/firebase_messaging.dart';

// Location
import 'package:geolocator/geolocator.dart';

// Health (HealthKit / Google Fit / Health Connect)
import 'package:health/health.dart';

// Optional helper for camera/photos on Android; iOS uses Info.plist prompts
import 'package:permission_handler/permission_handler.dart';

class ConsentManager {
  static bool? _healthAvailable;
  static bool _healthPermissionRequestInFlight = false;
  static Completer<void>? _healthPermissionGate;
  static bool? _unifiedHealthGrantedCache;
  static bool _unifiedHealthRequestCompletedThisSession = false;
  static bool _unifiedHealthRequestResult = false;
  static const String _unifiedHealthGrantedKey =
      'taqa_unified_health_permission_granted_v2';

  static Future<bool> _isAndroidHealthPromptCached() =>
      isAndroidHealthPromptCached();

  /// True once the user has been shown the unified Health Connect dialog at
  /// least once on Android. Callers that perform their own
  /// `requestAuthorization` checks should short-circuit when this is true to
  /// avoid re-prompting (Health Connect never reports grant state back).
  static Future<bool> isAndroidHealthPromptCached() async {
    if (_unifiedHealthGrantedCache == true) return true;
    final sp = await SharedPreferences.getInstance();
    if (sp.getBool(_unifiedHealthGrantedKey) == true) {
      _unifiedHealthGrantedCache = true;
      return true;
    }
    return false;
  }

  static Future<void> _markAndroidHealthPromptShown() async {
    _unifiedHealthGrantedCache = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_unifiedHealthGrantedKey, true);
  }

  // ---------------------------------------------------------------------------
  // STARTUP (call once)
  // ---------------------------------------------------------------------------
  static Future<void> requestStartupConsents() async {
    await _requestATTIfAvailable(); // iOS tracking (IDFA)
    await _requestNotifications(); // Push permission
    await ensureHealthConnectInstalled(); // Prompt Health Connect on Android if missing
    // Ask for every Dashboard health scope in one HealthKit/Health Connect
    // authorization sheet. Individual metric services reuse this request.
    await requestAllHealth();
  }

  // ---------------------------------------------------------------------------
  // ATT — App Tracking Transparency (iOS only)
  // ---------------------------------------------------------------------------
  static Future<void> _requestATTIfAvailable() async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // best practice: call after first frame or slight delay from main()
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {
      /* swallow in release */
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications — iOS + Android 13+
  // ---------------------------------------------------------------------------
  static Future<void> _requestNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false, // enable only if you have Apple entitlement
        provisional: false, // set true if you want "quiet" iOS auth
      );
      if (kDebugMode) {
        print("Notification authorization: ${settings.authorizationStatus}");
      }
    } catch (e) {
      if (kDebugMode) print('Notification permission error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION — JIT on features that need it
  // ---------------------------------------------------------------------------
  static Future<bool> requestLocationJIT() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      final granted =
          perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      if (!granted) return false;

      // If services are disabled, we can't get a fix.
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION — Background (iOS/Android). Requires foreground permission first.
  // ---------------------------------------------------------------------------
  static Future<bool> requestBackgroundLocationJIT() async {
    final ok = await requestLocationJIT();
    if (!ok) return false;

    if (Platform.isAndroid) {
      final bgStatus = await Permission.locationAlways.status;
      if (bgStatus.isGranted) return true;
      final res = await Permission.locationAlways.request();
      return res.isGranted;
    }

    if (Platform.isIOS) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always;
    }

    return true;
  }

  static Future<bool> hasBackgroundLocationPermission() async {
    if (Platform.isAndroid) {
      final bg = await Permission.locationAlways.status;
      return bg.isGranted;
    }
    if (Platform.isIOS) {
      final perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY RECOGNITION (Android steps via sensors; some devices require it)
  // Android 10+ requires runtime ACTIVITY_RECOGNITION.
  // ---------------------------------------------------------------------------
  static Future<bool> requestActivityRecognitionAndroid() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;
    final res = await Permission.activityRecognition.request();
    return res.isGranted;
  }

  // ---------------------------------------------------------------------------
  // HEALTH — compatibility entry point used by individual metric services.
  // ---------------------------------------------------------------------------
  static Future<bool> requestHealthPermissionsJIT({
    bool steps = true,
    bool sleep = true,
    bool calories = false,
  }) async {
    if (!steps && !sleep && !calories) return true;
    // All callers intentionally share the complete Dashboard scope. Asking
    // for subsets here caused iOS to show Sleep, Steps, and recovery sheets on
    // separate launches depending on which widget loaded first.
    return requestUnifiedHealthPermissionsJIT();
  }

  /// Legacy convenience helper; now joins the unified Dashboard request.
  static Future<bool> requestStepsAndSleep() =>
      requestHealthPermissionsJIT(steps: true, sleep: true);

  /// Legacy alias kept for existing call sites. Requests the full Dashboard
  /// and training health scope together in one prompt.
  static Future<bool> requestAllHealth() =>
      requestUnifiedHealthPermissionsJIT();

  /// Unified health prompt for every health type read by Dashboard, plus the
  /// workout/step write scopes used by training sync.
  static Future<bool> requestUnifiedHealthPermissionsJIT() async {
    // On Android, Health Connect's hasPermissions() always returns false even
    // when granted (intentional Google privacy design). We cache the granted
    // state ourselves so we never re-prompt after the user already said yes.
    if (Platform.isAndroid && await _isAndroidHealthPromptCached()) {
      _unifiedHealthRequestCompletedThisSession = true;
      _unifiedHealthRequestResult = true;
      return true;
    }

    if (_unifiedHealthRequestCompletedThisSession) {
      return _unifiedHealthRequestResult;
    }

    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WORKOUT,
    ];
    final permissions = <HealthDataAccess>[
      HealthDataAccess.READ_WRITE, // STEPS
      HealthDataAccess.READ, // ACTIVE_ENERGY_BURNED
      HealthDataAccess.READ_WRITE, // WORKOUT
    ];
    if (Platform.isIOS) {
      // TOTAL_CALORIES_BURNED is writable on HealthKit but read-only on Health
      // Connect — requesting WRITE for it on Android crashes the permission Activity.
      types.add(HealthDataType.TOTAL_CALORIES_BURNED);
      permissions.add(HealthDataAccess.WRITE);
      types.addAll([
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      ]);
      permissions.addAll(
        List<HealthDataAccess>.filled(10, HealthDataAccess.READ),
      );
    } else if (Platform.isAndroid) {
      types.addAll([
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      ]);
      permissions.addAll(
        List<HealthDataAccess>.filled(10, HealthDataAccess.READ),
      );
    }

    final health = Health();

    if (Platform.isAndroid) {
      if (_healthAvailable == null) {
        try {
          _healthAvailable = await health.isHealthConnectAvailable();
        } catch (e) {
          _healthAvailable = false;
          if (kDebugMode) {
            print("Health availability check failed: $e");
          }
        }
      }
      if (_healthAvailable == false) {
        return false;
      }
    }

    if (_healthPermissionRequestInFlight) {
      final gate = _healthPermissionGate;
      if (gate != null) {
        await gate.future;
      }
      return _unifiedHealthRequestCompletedThisSession
          ? _unifiedHealthRequestResult
          : false;
    }
    _healthPermissionRequestInFlight = true;
    _healthPermissionGate = Completer<void>();
    try {
      final has =
          await health.hasPermissions(types, permissions: permissions) ?? false;
      if (has) {
        if (Platform.isAndroid) {
          await _markAndroidHealthPromptShown();
        }
        _unifiedHealthRequestCompletedThisSession = true;
        _unifiedHealthRequestResult = true;
        return true;
      }
      final granted = await health.requestAuthorization(
        types,
        permissions: permissions,
      );
      if (Platform.isAndroid) {
        // Health Connect never confirms the grant result back to the app, so
        // we cache after the first prompt regardless — the user saw the dialog
        // and made their choice; we must not ask again on next app open.
        await _markAndroidHealthPromptShown();
      }
      _unifiedHealthRequestCompletedThisSession = true;
      // Health Connect does not reliably return its grant state. The user has
      // completed the sheet, so allow reads to resolve to data or empty values
      // without presenting the sheet again.
      _unifiedHealthRequestResult = Platform.isAndroid ? true : granted;
      return _unifiedHealthRequestResult;
    } catch (e) {
      if (kDebugMode) {
        print("Unified health permission request failed: $e");
      }
      return false;
    } finally {
      _healthPermissionRequestInFlight = false;
      _healthPermissionGate?.complete();
      _healthPermissionGate = null;
    }
  }

  /// Request permission to write workout sessions.
  static Future<bool> requestWorkoutWritePermissionJIT() async {
    // Already-prompted? Short-circuit on Android — same reason as above.
    if (Platform.isAndroid && await _isAndroidHealthPromptCached()) {
      return true;
    }

    final types = <HealthDataType>[HealthDataType.WORKOUT];
    if (Platform.isAndroid) {
      // TOTAL_CALORIES_BURNED is read-only on Health Connect — requesting
      // WRITE crashes the permission Activity.
      types.add(HealthDataType.STEPS);
    } else if (Platform.isIOS) {
      types.addAll([
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.STEPS,
      ]);
    }
    final permissions = types.map((_) => HealthDataAccess.WRITE).toList();
    final health = Health();

    if (Platform.isAndroid) {
      if (_healthAvailable == null) {
        try {
          _healthAvailable = await health.isHealthConnectAvailable();
        } catch (e) {
          _healthAvailable = false;
          if (kDebugMode) {
            print("Health availability check failed: $e");
          }
        }
      }
      if (_healthAvailable == false) {
        return false;
      }
    }

    if (_healthPermissionRequestInFlight) {
      final gate = _healthPermissionGate;
      if (gate != null) {
        await gate.future;
      }
    }
    _healthPermissionRequestInFlight = true;
    _healthPermissionGate = Completer<void>();
    try {
      final has =
          await health.hasPermissions(types, permissions: permissions) ?? false;
      if (has) {
        if (Platform.isAndroid) {
          await _markAndroidHealthPromptShown();
        }
        return true;
      }
      final granted = await health.requestAuthorization(
        types,
        permissions: permissions,
      );
      if (Platform.isAndroid) {
        await _markAndroidHealthPromptShown();
      }
      if (granted) return true;

      // Fallback: workout-only scope (still allows pushing workouts when
      // calories/distance permissions are denied or unsupported).
      const fallbackTypes = <HealthDataType>[HealthDataType.WORKOUT];
      const fallbackPermissions = <HealthDataAccess>[HealthDataAccess.WRITE];
      final hasFallback =
          await health.hasPermissions(
            fallbackTypes,
            permissions: fallbackPermissions,
          ) ??
          false;
      if (hasFallback) return true;
      final fallbackGranted = await health.requestAuthorization(
        fallbackTypes,
        permissions: fallbackPermissions,
      );
      if (Platform.isAndroid) {
        await _markAndroidHealthPromptShown();
      }
      return fallbackGranted;
    } catch (e) {
      if (kDebugMode) {
        print("Workout health permission request failed: $e");
      }
      return false;
    } finally {
      _healthPermissionRequestInFlight = false;
      _healthPermissionGate?.complete();
      _healthPermissionGate = null;
    }
  }

  // ---------------------------------------------------------------------------
  // HEALTH CONNECT INSTALL PROMPT (Android)
  // ---------------------------------------------------------------------------
  static Future<bool> ensureHealthConnectInstalled() async {
    if (!Platform.isAndroid) return true;
    try {
      final health = Health();
      final available = await health.isHealthConnectAvailable();
      if (available) return true;
      await health.installHealthConnect(); // opens Play Store flow
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Health Connect install check failed: $e");
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CAMERA — JIT (you’ll still need proper Info.plist/Manifest entries)
  // ---------------------------------------------------------------------------
  static Future<bool> requestCameraJIT() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final res = await Permission.camera.request();
    return res.isGranted;
  }

  // ---------------------------------------------------------------------------
  // PHOTOS / MEDIA LIBRARY — JIT (for saving/reading images)
  // ---------------------------------------------------------------------------
  static Future<bool> requestPhotosJIT() async {
    if (Platform.isAndroid) {
      // Android image/video flows use the system picker, which grants access
      // only to the item selected by the user and needs no broad permission.
      return true;
    }
    final photos = await Permission.photos.status;
    if (_isGrantedOrLimited(photos)) return true;
    final res = await Permission.photos.request();
    return _isGrantedOrLimited(res);
  }

  // Files/documents (PDF/images) for uploads
  static Future<bool> requestFileAccessJIT() async {
    if (Platform.isAndroid) {
      // FilePicker uses Android's Storage Access Framework. The selected
      // document receives a scoped URI grant; storage permission is not needed.
      return true;
    }
    // iOS prompts on first access.
    return true;
  }

  // ---------------------------------------------------------------------------
  // CAMERA or PHOTOS combo for avatar pickers
  // ---------------------------------------------------------------------------
  static bool _isGrantedOrLimited(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static Future<bool> requestCameraOrGalleryForAvatar() async {
    if (Platform.isAndroid) {
      // Avatar selection uses the Android system picker, not broad gallery
      // access. Camera permission is requested separately by camera flows.
      return true;
    }

    if (Platform.isIOS) {
      var photos = await Permission.photos.status;
      if (_isGrantedOrLimited(photos)) return true;

      photos = await Permission.photos.request();
      return _isGrantedOrLimited(photos);
    }

    return true; // other platforms: no-op
  }
}
