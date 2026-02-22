import 'dart:io';
import 'package:flutter/foundation.dart';

// ATT (iOS)
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// UMP (GDPR ads/consent — keep only if you’ll do personalized tracking/ads)
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Notifications
import 'package:firebase_messaging/firebase_messaging.dart';

// Location
import 'package:geolocator/geolocator.dart';

// Health (HealthKit / Google Fit / Health Connect)
import 'package:health/health.dart';

// Optional helper for camera/photos on Android; iOS uses Info.plist prompts
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';

class ConsentManager {
  static bool? _healthAvailable; // cache Health Connect / platform availability
  // ---------------------------------------------------------------------------
  // STARTUP (call once)
  // ---------------------------------------------------------------------------
  static Future<void> requestStartupConsents() async {
    await _requestATTIfAvailable();       // iOS tracking (IDFA)
    await _requestGDPRIfRequired();       // UMP (if you’ll personalize/ads)
    await _requestNotifications();        // Push permission
    await ensureHealthConnectInstalled(); // Prompt Health Connect on Android if missing
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
    } catch (_) {/* swallow in release */}
  }

  // ---------------------------------------------------------------------------
  // GDPR — UMP (show only if you have personalized tracking/ads)
  // ---------------------------------------------------------------------------
  static Future<void> _requestGDPRIfRequired() async {
    try {
      final params = ConsentRequestParameters();
      final consentInfo = ConsentInformation.instance;

      consentInfo.requestConsentInfoUpdate(
        params,
            () async {
          if (await consentInfo.isConsentFormAvailable()) {
            _loadAndHandleUMPForm(consentInfo);
          }
        },
            (FormError error) {
          if (kDebugMode) print("Consent info update failed: ${error.message}");
        },
      );
    } catch (e) {
      if (kDebugMode) print('UMP consent error: $e');
    }
  }

  static Future<void> _loadAndHandleUMPForm(
      ConsentInformation consentInfo,
      ) async {
    ConsentForm.loadConsentForm(
          (ConsentForm form) async {
        final status = await consentInfo.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((FormError? error) {
            if (error != null && kDebugMode) {
              print("Error showing UMP form: ${error.message}");
            }
          });
        }
      },
          (FormError error) {
        if (kDebugMode) print("Failed to load UMP form: ${error.message}");
      },
    );
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
        provisional: false,   // set true if you want "quiet" iOS auth
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
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      final granted = perm == LocationPermission.always ||
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
  // HEALTH — Steps & Sleep (HealthKit on iOS, Google Fit/Health Connect on Android)
  // Call this JIT before you try to read health data.
  // ---------------------------------------------------------------------------
  static Future<bool> requestHealthPermissionsJIT({
    bool steps = true,
    bool sleep = true,
    bool calories = false,
  }) async {
    final types = <HealthDataType>[];
    if (steps) types.add(HealthDataType.STEPS);
    if (sleep) {
      // Request both sleep types together so iOS shows a single HealthKit sheet.
      types.addAll([
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_IN_BED,
      ]);
    }
    if (calories) types.add(HealthDataType.ACTIVE_ENERGY_BURNED);

    if (types.isEmpty) return true;

    // Some platforms split permissions by READ/WRITE
    final permissions = types.map((_) => HealthDataAccess.READ).toList();

    final health = Health();

    // On Android emulators/devices without Health Connect or Google Fit, short-circuit
    // to avoid spamming logs with repeated failures.
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
        if (kDebugMode) {
          print("Health availability (Health Connect): $_healthAvailable");
        }
      }
      if (_healthAvailable == false) {
        return false;
      }
    }

    try {
      final has = await health.hasPermissions(types, permissions: permissions) ?? false;
      if (has) return true;

      final granted = await health.requestAuthorization(types, permissions: permissions);
      return granted;
    } catch (e) {
      if (kDebugMode) {
        print("Health permission check failed (possibly missing Health Connect): $e");
      }
      return false;
    }
  }

  /// Convenience helper to request both steps + sleep at once.
  static Future<bool> requestStepsAndSleep() =>
      requestHealthPermissionsJIT(steps: true, sleep: true);

  /// Convenience helper to request steps + sleep + calories in one prompt.
  static Future<bool> requestAllHealth() =>
      requestHealthPermissionsJIT(steps: true, sleep: true, calories: true);

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
    if (Platform.isAndroid) {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final res = await Permission.camera.request();
      return res.isGranted;
    }
    // iOS prompts automatically on first camera use if Info.plist key exists.
    return true;
  }

  // ---------------------------------------------------------------------------
  // PHOTOS / MEDIA LIBRARY — JIT (for saving/reading images)
  // ---------------------------------------------------------------------------
  static Future<bool> requestPhotosJIT() async {
    if (Platform.isAndroid) {
      // Android 13 split media permissions; pick what you need.
      final photos = await Permission.photos.status; // aliases READ_MEDIA_IMAGES on new SDKs
      if (photos.isGranted) return true;
      final res = await Permission.photos.request();
      return res.isGranted;
    }
    // iOS prompts on first access if the proper Info.plist keys exist.
    return true;
  }

  // Files/documents (PDF/images) for uploads
  static Future<bool> requestFileAccessJIT() async {
    if (Platform.isAndroid) {
      // Try media/photos first, then fall back to storage for PDFs.
      var photos = await Permission.photos.status;
      if (_isGrantedOrLimited(photos)) return true;

      photos = await Permission.photos.request();
      if (_isGrantedOrLimited(photos)) return true;

      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    // iOS prompts on first access.
    return true;
  }

  // ---------------------------------------------------------------------------
  // CAMERA or PHOTOS combo for avatar pickers
  // ---------------------------------------------------------------------------
  static bool _isGrantedOrLimited(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static Future<bool> _requestAndroidGalleryPermission() async {
    // Android 13+: photos permission, Android 12-: storage fallback.
    var photos = await Permission.photos.status;
    if (_isGrantedOrLimited(photos)) return true;

    photos = await Permission.photos.request();
    if (_isGrantedOrLimited(photos)) return true;

    var storage = await Permission.storage.status;
    if (storage.isGranted) return true;

    storage = await Permission.storage.request();
    return storage.isGranted;
  }

  static Future<bool> requestCameraOrGalleryForAvatar() async {
    if (Platform.isAndroid) {
      final cam = await Permission.camera.status;
      if (!cam.isGranted) {
        final res = await Permission.camera.request();
        if (!res.isGranted) return false;
      }
      return _requestAndroidGalleryPermission();
    }

    if (Platform.isIOS) {
      final cam = await Permission.camera.status;
      if (!_isGrantedOrLimited(cam)) {
        final res = await Permission.camera.request();
        if (!_isGrantedOrLimited(res)) return false;
      }

      var photos = await Permission.photos.status;
      if (_isGrantedOrLimited(photos)) return true;

      photos = await Permission.photos.request();
      return _isGrantedOrLimited(photos);
    }

    return true; // other platforms: no-op
  }
}
