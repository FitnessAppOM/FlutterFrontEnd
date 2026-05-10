import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

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
  static const _deviceIdStorageKey = 'remote_push_device_id';
  static const _currentPushTokenRefreshEpoch = 'ios_prod_apns_2026_05_04';

  static bool _initialized = false;
  static int? _lastSyncedUserId;
  static String? _lastSyncedToken;
  static String? _cachedDeviceId;

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _ensureFcmPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        final title =
            message.notification?.title ??
            message.data['notification_title']?.toString().trim() ??
            message.data['title']?.toString().trim() ??
            '';
        final body =
            message.notification?.body ??
            message.data['notification_body']?.toString().trim() ??
            message.data['body']?.toString().trim() ??
            message.data['message']?.toString().trim() ??
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
      syncTokenForCurrentUser(
        force: true,
        tokenOverride: token,
      ).catchError((_) {});
    });

    // Ensure current token is registered even when no account-change event
    // occurs in this app run (e.g. returning user opening app fresh).
    syncTokenForCurrentUser().catchError((_) {});
  }

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static int? _firstIntFromKeys(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final parsed = _parseIntOrNull(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static void _handleNotificationTapData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    if (type.isEmpty) return;
    final senderUserId = _firstIntFromKeys(data, const [
      'sender_user_id',
      'senderUserId',
      'sender_id',
      'senderId',
      'user_id',
      'userId',
    ]);
    final clientUserId = _firstIntFromKeys(data, const [
      'client_user_id',
      'clientUserId',
      'client_id',
      'clientId',
      'sender_user_id',
      'senderUserId',
      'sender_id',
      'senderId',
    ]);
    final coachUserId = _firstIntFromKeys(data, const [
      'coach_user_id',
      'coachUserId',
      'coach_id',
      'coachId',
    ]);
    final senderRole =
        (data['sender_role'] ??
                data['senderRole'] ??
                data['from_role'] ??
                data['fromRole'] ??
                data['role'])
        ?.toString()
        .trim();

    NavigationService.handleNotificationTap(
      type: type,
      senderUserId: senderUserId,
      senderRole: senderRole,
      clientUserId: clientUserId,
      coachUserId: coachUserId,
    );
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

  static Future<String> _resolveDeviceId() async {
    final cached = (_cachedDeviceId ?? '').trim();
    if (cached.isNotEmpty) return cached;

    final prefs = await SharedPreferences.getInstance();
    final fromStorage = (prefs.getString(_deviceIdStorageKey) ?? '').trim();
    if (fromStorage.isNotEmpty) {
      _cachedDeviceId = fromStorage;
      return fromStorage;
    }

    final rnd = Random.secure();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final entropy = List.generate(
      16,
      (_) => rnd.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final generated = 'rp-$ts-$entropy';
    await prefs.setString(_deviceIdStorageKey, generated);
    _cachedDeviceId = generated;
    return generated;
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

    String appVersion = '';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}
    String deviceId = '';
    try {
      deviceId = await _resolveDeviceId();
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
          'device_id': deviceId,
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
