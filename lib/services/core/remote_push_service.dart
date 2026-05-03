import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'navigation_service.dart';
import 'notification_service.dart';

class RemotePushService {
  static const _firebaseAppIdStorageKey = 'remote_push_firebase_app_id';
  static const _pushTokenRefreshEpochKey = 'remote_push_token_refresh_epoch';
  static const _currentPushTokenRefreshEpoch = 'ios_prod_apns_2026_05_04';

  static bool _initialized = false;
  static int? _lastSyncedUserId;
  static String? _lastSyncedToken;
  static String? _lastLoggedToken;

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _ensureFcmPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        final title =
            message.notification?.title ??
            message.data['title']?.toString().trim() ??
            '';
        final body =
            message.notification?.body ??
            message.data['body']?.toString().trim() ??
            '';
        if (title.isEmpty && body.isEmpty) return;
        await NotificationService.showRemoteMessageNow(
          title: title,
          body: body,
          payload: jsonEncode(message.data),
        );
      } catch (_) {}
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTapData(message.data);
    });

    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTapData(initialMessage.data);
      }
    } catch (_) {}

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      if (kDebugMode) {
        debugPrint('[Push] FCM TOKEN REFRESHED: $token');
      }
      syncTokenForCurrentUser(
        force: true,
        tokenOverride: token,
      ).catchError((_) {});
    });
  }

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static void _handleNotificationTapData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    if (type.isEmpty) return;

    if (type == 'coach_chat') {
      final senderUserId = _parseIntOrNull(data['sender_user_id']);
      final senderRole = (data['sender_role'] ?? data['senderRole'])
          ?.toString()
          .trim();
      NavigationService.navigateToChatFromNotification(
        senderUserId: senderUserId,
        senderRole: senderRole,
      );
      return;
    }
    if (type == 'habit_reminder') {
      NavigationService.navigateToCoachFeedback();
      return;
    }
    if (type == 'training_plan_change') {
      NavigationService.navigateToTrain(fromNotification: true);
      return;
    }
    if (type == 'coach_feedback_added' || type == 'coach_habit_added') {
      NavigationService.navigateToCoachFeedback();
      return;
    }
    if (type == 'coach_connection_request_decision') {
      NavigationService.navigateToCoachFeedback();
    }
  }

  static Future<void> _ensureFcmPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      if (kDebugMode) {
        debugPrint('[Push] FCM permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] FCM permission request failed: $e');
      }
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static Future<String> _currentFirebaseAppId() async {
    try {
      return Firebase.app().options.appId.trim();
    } catch (_) {
      return '';
    }
  }

  static Future<bool> _deleteCachedTokenIfNeeded() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) return false;

    final currentAppId = await _currentFirebaseAppId();
    if (currentAppId.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final previousAppId = prefs.getString(_firebaseAppIdStorageKey)?.trim();
    final previousEpoch = prefs.getString(_pushTokenRefreshEpochKey)?.trim();
    if (previousAppId == currentAppId &&
        previousEpoch == _currentPushTokenRefreshEpoch) {
      return false;
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
      _lastSyncedToken = null;
      _lastLoggedToken = null;
      if (kDebugMode) {
        debugPrint(
          '[Push] Deleted cached FCM token: '
          'app=${previousAppId ?? "(none)"}->$currentAppId '
          'epoch=${previousEpoch ?? "(none)"}->$_currentPushTokenRefreshEpoch',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Failed to delete cached FCM token: $e');
      }
      return false;
    }
  }

  static Future<void> syncTokenForCurrentUser({
    bool force = false,
    String? tokenOverride,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) return;

    final headers = await AccountStorage.getAuthHeaders();
    if (!headers.containsKey('Authorization')) return;

    String token = (tokenOverride ?? '').trim();
    final refreshedCachedToken = token.isEmpty
        ? await _deleteCachedTokenIfNeeded()
        : false;
    if (token.isEmpty) {
      try {
        token = (await FirebaseMessaging.instance.getToken() ?? '').trim();
      } catch (_) {
        return;
      }
    }
    if (token.isEmpty) return;

    if (!force &&
        !refreshedCachedToken &&
        _lastSyncedUserId == userId &&
        _lastSyncedToken == token) {
      return;
    }

    if (kDebugMode && _lastLoggedToken != token) {
      debugPrint('[Push] FCM TOKEN: $token');
      _lastLoggedToken = token;
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        try {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          debugPrint('[Push] APNS TOKEN: ${apnsToken ?? "(null)"}');
        } catch (e) {
          debugPrint('[Push] APNS TOKEN ERROR: $e');
        }
      }
    }

    String appVersion = '';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}

    final reqHeaders = <String, String>{
      ...headers,
      'Content-Type': 'application/json',
    };
    try {
      final response = await http.post(
        _uri('/push/device-token'),
        headers: reqHeaders,
        body: jsonEncode({
          'token': token,
          'platform': _platformName(),
          'app_version': appVersion,
        }),
      );
      await AccountStorage.handleAuthStatus(
        response.statusCode,
        responseBody: response.body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastSyncedUserId = userId;
        _lastSyncedToken = token;
        final currentAppId = await _currentFirebaseAppId();
        if (currentAppId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_firebaseAppIdStorageKey, currentAppId);
          await prefs.setString(
            _pushTokenRefreshEpochKey,
            _currentPushTokenRefreshEpoch,
          );
        }
        if (kDebugMode) {
          debugPrint(
            '[Push] Token sync OK (user=$userId, platform=${_platformName()})',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '[Push] Token sync failed: status=${response.statusCode} body=${response.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Token sync exception: $e');
      }
      return;
    }
  }
}
