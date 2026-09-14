import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayInAppUpdateStatus {
  idle,
  available,
  pending,
  downloading,
  downloaded,
  installing,
}

/// Flutter bridge for Google Play's official flexible in-app update API.
///
/// Failures are intentionally silent because update checks are best-effort and
/// are expected to fail for debug builds or apps not installed by Google Play.
class PlayInAppUpdateService extends ChangeNotifier {
  PlayInAppUpdateService._();

  static final PlayInAppUpdateService instance = PlayInAppUpdateService._();

  static const MethodChannel _channel = MethodChannel(
    'taqa/play_in_app_update',
  );
  static const _dismissedPrefix = 'play_update_dismissed';
  static const _dismissDuration = Duration(days: 1);

  bool _initialized = false;
  bool _checking = false;
  PlayInAppUpdateStatus _status = PlayInAppUpdateStatus.idle;
  int? _availableVersionCode;
  double? _downloadProgress;

  PlayInAppUpdateStatus get status => _status;
  int? get availableVersionCode => _availableVersionCode;
  double? get downloadProgress => _downloadProgress;
  bool get isVisible => _status != PlayInAppUpdateStatus.idle;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    await checkForUpdate();
  }

  Future<void> checkForUpdate({bool respectDismissal = true}) async {
    if (!_isSupported || _checking) return;
    if (_status == PlayInAppUpdateStatus.downloading ||
        _status == PlayInAppUpdateStatus.downloaded ||
        _status == PlayInAppUpdateStatus.installing) {
      return;
    }
    _checking = true;
    try {
      final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
        'checkForUpdate',
      );
      final data = raw ?? const <dynamic, dynamic>{};
      final installStatus = data['installStatus']?.toString();
      if (installStatus == 'downloaded') {
        _setStatus(PlayInAppUpdateStatus.downloaded);
        return;
      }
      if (installStatus == 'downloading' || installStatus == 'pending') {
        _setStatus(
          installStatus == 'downloading'
              ? PlayInAppUpdateStatus.downloading
              : PlayInAppUpdateStatus.pending,
        );
        return;
      }

      final available = data['available'] == true;
      final flexibleAllowed = data['flexibleAllowed'] == true;
      final version = _asInt(data['availableVersionCode']);
      _availableVersionCode = version;
      if (!available || !flexibleAllowed) {
        _setStatus(PlayInAppUpdateStatus.idle);
        return;
      }
      if (respectDismissal &&
          version != null &&
          await _wasDismissedRecently(version)) {
        _setStatus(PlayInAppUpdateStatus.idle);
        return;
      }
      _setStatus(PlayInAppUpdateStatus.available);
    } on PlatformException {
      // Expected when the app was sideloaded or Google Play is unavailable.
    } catch (_) {
      // Update discovery must never interfere with normal app startup.
    } finally {
      _checking = false;
    }
  }

  Future<bool> startFlexibleUpdate() async {
    if (!_isSupported || _status != PlayInAppUpdateStatus.available) {
      return false;
    }
    _setStatus(PlayInAppUpdateStatus.pending);
    try {
      final started =
          await _channel.invokeMethod<bool>('startFlexibleUpdate') ?? false;
      if (!started) {
        _setStatus(PlayInAppUpdateStatus.idle);
      }
      return started;
    } catch (_) {
      _setStatus(PlayInAppUpdateStatus.available);
      return false;
    }
  }

  Future<bool> completeFlexibleUpdate() async {
    if (!_isSupported || _status != PlayInAppUpdateStatus.downloaded) {
      return false;
    }
    _setStatus(PlayInAppUpdateStatus.installing);
    try {
      return await _channel.invokeMethod<bool>('completeFlexibleUpdate') ??
          false;
    } catch (_) {
      _setStatus(PlayInAppUpdateStatus.downloaded);
      return false;
    }
  }

  Future<void> dismissForToday() async {
    final version = _availableVersionCode;
    if (version != null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        '${_dismissedPrefix}_v$version',
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    _setStatus(PlayInAppUpdateStatus.idle);
  }

  Future<bool> _wasDismissedRecently(int version) async {
    final preferences = await SharedPreferences.getInstance();
    final dismissedAt = preferences.getInt('${_dismissedPrefix}_v$version');
    if (dismissedAt == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(dismissedAt),
    );
    return !elapsed.isNegative && elapsed < _dismissDuration;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    final arguments = call.arguments;
    final data = arguments is Map ? arguments : const <dynamic, dynamic>{};
    switch (call.method) {
      case 'onInstallStateChanged':
        _handleInstallState(data);
        return;
      case 'onUpdateFlowResult':
        final resultCode = _asInt(data['resultCode']);
        if (resultCode == 0) {
          await dismissForToday();
        } else if (resultCode != -1 &&
            _status == PlayInAppUpdateStatus.pending) {
          _setStatus(PlayInAppUpdateStatus.available);
        }
        return;
    }
  }

  void _handleInstallState(Map data) {
    switch (data['status']?.toString()) {
      case 'pending':
        _setStatus(PlayInAppUpdateStatus.pending);
        return;
      case 'downloading':
        final downloaded = _asInt(data['bytesDownloaded']) ?? 0;
        final total = _asInt(data['totalBytesToDownload']) ?? 0;
        _downloadProgress = total > 0
            ? (downloaded / total).clamp(0.0, 1.0)
            : null;
        _setStatus(PlayInAppUpdateStatus.downloading);
        return;
      case 'downloaded':
        _downloadProgress = 1;
        _setStatus(PlayInAppUpdateStatus.downloaded);
        return;
      case 'installing':
        _setStatus(PlayInAppUpdateStatus.installing);
        return;
      case 'installed':
        _setStatus(PlayInAppUpdateStatus.idle);
        return;
      case 'canceled':
        unawaited(dismissForToday());
        return;
      case 'failed':
        _setStatus(PlayInAppUpdateStatus.available);
        return;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _setStatus(PlayInAppUpdateStatus next) {
    if (_status == next) {
      notifyListeners();
      return;
    }
    _status = next;
    notifyListeners();
  }
}
