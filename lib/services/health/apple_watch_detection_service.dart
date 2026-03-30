import 'dart:io';

import 'package:health/health.dart';

class AppleWatchDetectionService {
  final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
  ];

  static final List<HealthDataAccess> _permissions =
      List<HealthDataAccess>.filled(_types.length, HealthDataAccess.READ);

  Future<bool> detect({
    bool requestPermissionIfNeeded = false,
    Duration lookback = const Duration(days: 30),
  }) async {
    if (!Platform.isIOS) return false;

    try {
      var hasPermission =
          await _health.hasPermissions(_types, permissions: _permissions) ??
          false;
      if (!hasPermission) {
        if (!requestPermissionIfNeeded) return false;
        hasPermission = await _health.requestAuthorization(
          _types,
          permissions: _permissions,
        );
        if (!hasPermission) return false;
      }

      final now = DateTime.now();
      final start = now.subtract(lookback);
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: _types,
      );

      for (final sample in samples) {
        final source =
            "${sample.sourceName} ${sample.sourceId} ${sample.deviceModel ?? ''}"
                .toLowerCase();
        if (source.contains('apple watch') || source.contains('watch')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
