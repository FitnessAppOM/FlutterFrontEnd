import 'dart:io';

import 'package:health/health.dart';

class HealthHeartZones {
  const HealthHeartZones({
    required this.outOfRangeMinutes,
    required this.fatBurnMinutes,
    required this.cardioMinutes,
    required this.peakMinutes,
  });

  final int outOfRangeMinutes;
  final int fatBurnMinutes;
  final int cardioMinutes;
  final int peakMinutes;

  int get totalMinutes =>
      outOfRangeMinutes + fatBurnMinutes + cardioMinutes + peakMinutes;
}

class HealthRecoveryLoadSummary {
  const HealthRecoveryLoadSummary({
    this.restingHeartRate,
    this.hrvMs,
    this.activeMinutes,
    this.zones,
  });

  final int? restingHeartRate;
  final double? hrvMs;
  final int? activeMinutes;
  final HealthHeartZones? zones;

  bool get hasAnyData =>
      (restingHeartRate ?? 0) > 0 ||
      (hrvMs ?? 0) > 0 ||
      (activeMinutes ?? 0) > 0 ||
      (zones?.totalMinutes ?? 0) > 0;
}

class HealthRecoveryLoadService {
  final Health _health = Health();

  static const List<HealthDataType> _commonTypes = [
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];
  static const List<HealthDataType> _iosTypes = [
    HealthDataType.EXERCISE_TIME,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];
  static const List<HealthDataType> _androidTypes = [
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  ];

  List<HealthDataType> _typesForPlatform() {
    if (Platform.isAndroid) return [..._commonTypes, ..._androidTypes];
    if (Platform.isIOS) return [..._commonTypes, ..._iosTypes];
    return _commonTypes;
  }

  Future<bool> _ensurePermission() async {
    try {
      final types = _typesForPlatform();
      final permissions = List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
      );
      var granted =
          await _health.hasPermissions(types, permissions: permissions) ??
          false;
      if (!granted) {
        granted = await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _valueToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    if (value is HealthValue) {
      final dynamic numeric = (value as dynamic).numericValue;
      if (numeric is num) return numeric.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _sampleMinutes(HealthDataPoint sample) {
    final mins = sample.dateTo.difference(sample.dateFrom).inMinutes;
    return mins > 0 ? mins : 1;
  }

  int _sumExerciseMinutes(Iterable<HealthDataPoint> samples) {
    var total = 0.0;
    for (final sample in samples) {
      final raw = _valueToDouble(sample.value);
      if (raw > 0) {
        total += raw;
      }
    }
    return total.round();
  }

  int _sumWorkoutMinutes(Iterable<HealthDataPoint> samples) {
    var total = 0;
    for (final sample in samples) {
      total += _sampleMinutes(sample);
    }
    return total;
  }

  HealthHeartZones? _buildZones(Iterable<HealthDataPoint> heartSamples) {
    var outOfRange = 0;
    var fatBurn = 0;
    var cardio = 0;
    var peak = 0;

    for (final sample in heartSamples) {
      final bpm = _valueToDouble(sample.value);
      if (bpm <= 0) continue;
      final minutes = _sampleMinutes(sample);
      if (bpm < 90) {
        outOfRange += minutes;
      } else if (bpm < 120) {
        fatBurn += minutes;
      } else if (bpm < 150) {
        cardio += minutes;
      } else {
        peak += minutes;
      }
    }

    final zones = HealthHeartZones(
      outOfRangeMinutes: outOfRange,
      fatBurnMinutes: fatBurn,
      cardioMinutes: cardio,
      peakMinutes: peak,
    );
    return zones.totalMinutes > 0 ? zones : null;
  }

  Future<HealthRecoveryLoadSummary?> fetchSummary(DateTime day) async {
    final granted = await _ensurePermission();
    if (!granted) return null;

    final start = DateTime(day.year, day.month, day.day);
    final now = DateTime.now();
    final end = _isSameDay(start, DateTime(now.year, now.month, now.day))
        ? now
        : start.add(const Duration(days: 1));

    try {
      final types = _typesForPlatform();
      final samples = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );

      final restingSamples = samples
          .where((s) => s.type == HealthDataType.RESTING_HEART_RATE)
          .toList()
        ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
      int? restingHr;
      if (restingSamples.isNotEmpty) {
        final v = _valueToDouble(restingSamples.last.value).round();
        restingHr = v > 0 ? v : null;
      }

      final hrvType = Platform.isIOS
          ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
          : HealthDataType.HEART_RATE_VARIABILITY_RMSSD;
      final hrvValues = samples
          .where((s) => s.type == hrvType)
          .map((s) => _valueToDouble(s.value))
          .where((v) => v > 0)
          .toList();
      double? hrvMs;
      if (hrvValues.isNotEmpty) {
        hrvMs = hrvValues.reduce((a, b) => a + b) / hrvValues.length;
      }

      final exerciseSamples = samples.where(
        (s) => s.type == HealthDataType.EXERCISE_TIME,
      );
      var activeMinutes = _sumExerciseMinutes(exerciseSamples);
      if (activeMinutes <= 0) {
        activeMinutes = _sumWorkoutMinutes(
          samples.where((s) => s.type == HealthDataType.WORKOUT),
        );
      }
      final resolvedActiveMinutes = activeMinutes > 0 ? activeMinutes : null;

      final zones = _buildZones(
        samples.where((s) => s.type == HealthDataType.HEART_RATE),
      );

      final summary = HealthRecoveryLoadSummary(
        restingHeartRate: restingHr,
        hrvMs: hrvMs,
        activeMinutes: resolvedActiveMinutes,
        zones: zones,
      );
      return summary.hasAnyData ? summary : null;
    } catch (_) {
      return null;
    }
  }
}
