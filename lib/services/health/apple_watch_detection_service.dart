import 'dart:io';

import 'package:health/health.dart';

enum WearableDetectionKind { none, apple, other }

class WearableDetectionResult {
  const WearableDetectionResult(this.kind);

  final WearableDetectionKind kind;

  bool get detected => kind != WearableDetectionKind.none;
}

class AppleWatchDetectionService {
  final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

  static final List<HealthDataAccess> _permissions =
      List<HealthDataAccess>.filled(_types.length, HealthDataAccess.READ);

  static const List<String> _otherWearableKeywords = [
    'garmin',
    'fitbit',
    'whoop',
    'oura',
    'polar',
    'coros',
    'suunto',
    'huawei',
    'amazfit',
    'xiaomi',
    'mi band',
    'samsung watch',
    'galaxy watch',
    'wear os',
    'withings',
    'wahoo',
    'band',
  ];

  bool _isAppleWatchSource(String source) {
    return source.contains('apple watch');
  }

  bool _isOtherWearableSource(String source) {
    if (source.contains('iphone') ||
        source.contains('ipad') ||
        source.contains('health app')) {
      return false;
    }
    if (source.contains('watch') && !_isAppleWatchSource(source)) {
      return true;
    }
    return _otherWearableKeywords.any(source.contains);
  }

  Future<WearableDetectionResult> detectAny({
    bool requestPermissionIfNeeded = false,
    Duration lookback = const Duration(days: 30),
  }) async {
    if (!Platform.isIOS) {
      return const WearableDetectionResult(WearableDetectionKind.none);
    }

    try {
      var hasPermission =
          await _health.hasPermissions(_types, permissions: _permissions) ??
          false;
      if (!hasPermission) {
        if (!requestPermissionIfNeeded) {
          return const WearableDetectionResult(WearableDetectionKind.none);
        }
        hasPermission = await _health.requestAuthorization(
          _types,
          permissions: _permissions,
        );
        if (!hasPermission) {
          return const WearableDetectionResult(WearableDetectionKind.none);
        }
      }

      final now = DateTime.now();
      final start = now.subtract(lookback);
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _types,
      );

      var hasOtherWearable = false;
      for (final sample in samples) {
        final source =
            "${sample.sourceName} ${sample.sourceId} ${sample.deviceModel ?? ''}"
                .toLowerCase();
        if (_isAppleWatchSource(source)) {
          return const WearableDetectionResult(WearableDetectionKind.apple);
        }
        if (_isOtherWearableSource(source)) {
          hasOtherWearable = true;
        }
      }

      if (hasOtherWearable) {
        return const WearableDetectionResult(WearableDetectionKind.other);
      }
      return const WearableDetectionResult(WearableDetectionKind.none);
    } catch (_) {
      return const WearableDetectionResult(WearableDetectionKind.none);
    }
  }

  Future<bool> detect({
    bool requestPermissionIfNeeded = false,
    Duration lookback = const Duration(days: 30),
  }) async {
    final result = await detectAny(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
      lookback: lookback,
    );
    return result.detected;
  }
}
