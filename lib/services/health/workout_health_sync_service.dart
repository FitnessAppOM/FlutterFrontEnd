import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../consents/consent_manager.dart';
import '../auth/profile_storage.dart';
import '../training/training_calorie_estimator.dart';

enum WorkoutSessionWriteStatus { written, skippedDuplicate, failed }

class WorkoutSessionWriteResult {
  const WorkoutSessionWriteResult._(this.status);

  final WorkoutSessionWriteStatus status;

  static const WorkoutSessionWriteResult written = WorkoutSessionWriteResult._(
    WorkoutSessionWriteStatus.written,
  );
  static const WorkoutSessionWriteResult skippedDuplicate =
      WorkoutSessionWriteResult._(WorkoutSessionWriteStatus.skippedDuplicate);
  static const WorkoutSessionWriteResult failed = WorkoutSessionWriteResult._(
    WorkoutSessionWriteStatus.failed,
  );

  bool get isSuccess => status != WorkoutSessionWriteStatus.failed;
}

class WorkoutHealthSyncService {
  final Health _health = Health();
  static const MethodChannel _iosWorkoutMetadataChannel = MethodChannel(
    'health_workout_metadata',
  );
  static const Duration _dedupeWindow = Duration(seconds: 8);
  static const int _maxStoredDedupeSignatures = 6000;
  static const String _dedupeSignaturesStorageKey =
      'taqa_health_workout_dedupe_signatures_v2';

  Set<String>? _dedupeSignatureCache;

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  bool _hasExplicitTimezone(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.endsWith('Z')) return true;
    return RegExp(r'([+-]\d{2}:?\d{2})$').hasMatch(normalized);
  }

  DateTime? _parseBackendDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is num) {
      final intVal = value.toInt();
      if (intVal > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          intVal,
          isUtc: true,
        ).toLocal();
      }
      if (intVal > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          intVal * 1000,
          isUtc: true,
        ).toLocal();
      }
      return null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    DateTime? dt;
    if (!_hasExplicitTimezone(normalized)) {
      dt = DateTime.tryParse('${normalized}Z');
    }
    dt ??= DateTime.tryParse(normalized);
    return dt?.toLocal();
  }

  int _stableHash(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }

  String _normalizeSignaturePart(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('|', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  Future<Set<String>> _loadDedupeSignatures() async {
    final cached = _dedupeSignatureCache;
    if (cached != null) return cached;
    final sp = await SharedPreferences.getInstance();
    final stored = sp.getStringList(_dedupeSignaturesStorageKey) ?? const [];
    final set = stored.map(_normalizeSignaturePart).toSet();
    _dedupeSignatureCache = set;
    return set;
  }

  Future<bool> _isDedupeSignatureKnown(String signature) async {
    final known = await _loadDedupeSignatures();
    return known.contains(signature);
  }

  Future<void> _rememberDedupeSignature(String signature) async {
    final normalized = _normalizeSignaturePart(signature);
    if (normalized.isEmpty) return;
    final known = await _loadDedupeSignatures();
    if (known.contains(normalized)) return;
    known.add(normalized);
    if (known.length > _maxStoredDedupeSignatures) {
      final trimBy = known.length - _maxStoredDedupeSignatures;
      final sorted = known.toList()..sort();
      for (int i = 0; i < trimBy; i++) {
        known.remove(sorted[i]);
      }
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_dedupeSignaturesStorageKey, known.toList());
  }

  String _dateToken(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String buildTrainingHistoryDayDedupeSignature({
    required DateTime day,
    int? trainingDayId,
    String? dayKey,
    String? label,
  }) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final dayToken = _dateToken(normalizedDay);
    final normalizedLabel = _normalizeSignaturePart(label ?? '');
    if (normalizedLabel.isNotEmpty) {
      return 'training_history_day|$dayToken|label:$normalizedLabel';
    }
    final dayId = trainingDayId ?? 0;
    if (dayId > 0) {
      return 'training_history_day|$dayToken|id:$dayId';
    }
    final normalizedDayKey = _normalizeSignaturePart(dayKey ?? '');
    if (normalizedDayKey.isNotEmpty) {
      return 'training_history_day|$dayToken|key:$normalizedDayKey';
    }
    return 'training_history_day|$dayToken|label:training day';
  }

  String _workoutDedupeSignature({
    required DateTime start,
    required DateTime end,
    required HealthWorkoutActivityType type,
    required String title,
    String? custom,
  }) {
    final customTrimmed = custom?.trim();
    if (customTrimmed != null && customTrimmed.isNotEmpty) {
      return 'custom|${_normalizeSignaturePart(customTrimmed)}';
    }
    return [
      'workout',
      type.name.toLowerCase(),
      start.toUtc().millisecondsSinceEpoch.toString(),
      end.toUtc().millisecondsSinceEpoch.toString(),
      _normalizeSignaturePart(title),
    ].join('|');
  }

  DateTime _seedCardioSessionEnd({
    required DateTime baseDay,
    required String seedKey,
  }) {
    final normalizedDay = DateTime(baseDay.year, baseDay.month, baseDay.day);
    final startOfWindow = DateTime(
      normalizedDay.year,
      normalizedDay.month,
      normalizedDay.day,
      4,
    );
    final minuteOffset = _stableHash(seedKey) % (18 * 60);
    return startOfWindow.add(Duration(minutes: minuteOffset));
  }

  String _cardioHistoryDedupeSignature({
    required Map<String, dynamic> item,
    required String title,
    required int durationSeconds,
    required int? distanceMeters,
    required int? stepsCount,
  }) {
    final sessionId = _toInt(item['id']);
    if (sessionId > 0) {
      return 'cardio_history|session_id|$sessionId';
    }
    final entryDate = _parseBackendDateTime(item['entry_date']);
    final startedAt =
        _parseBackendDateTime(item['started_at']) ??
        _parseBackendDateTime(item['start_time']);
    final endedAt =
        _parseBackendDateTime(item['ended_at']) ??
        _parseBackendDateTime(item['finished_at']) ??
        _parseBackendDateTime(item['end_time']);
    return [
      'cardio_history',
      _normalizeSignaturePart(title),
      durationSeconds.toString(),
      (distanceMeters ?? 0).toString(),
      (stepsCount ?? 0).toString(),
      entryDate != null ? _dateToken(entryDate) : '',
      startedAt?.toUtc().millisecondsSinceEpoch.toString() ?? '',
      endedAt?.toUtc().millisecondsSinceEpoch.toString() ?? '',
      (item['created_at'] ?? '').toString().trim(),
      (item['updated_at'] ?? '').toString().trim(),
    ].join('|');
  }

  Future<double?> _loadWeightKg() async {
    final profile = await ProfileStorage.loadProfile();
    if (profile == null) return null;
    return _toDouble(profile['weight_kg']);
  }

  HealthWorkoutActivityType _activityTypeFromName(
    String? exerciseName, {
    required bool isCardio,
  }) {
    final n = (exerciseName ?? '').toLowerCase();

    // Cardio-first mapping to avoid weird name collisions (e.g. "Assault Bike Run").
    if (n.contains('elliptical') || n.contains('cross trainer')) {
      return HealthWorkoutActivityType.ELLIPTICAL;
    }
    if (n.contains('treadmill')) {
      if (n.contains('walk')) {
        return Platform.isAndroid
            ? HealthWorkoutActivityType.WALKING_TREADMILL
            : HealthWorkoutActivityType.WALKING;
      }
      return Platform.isAndroid
          ? HealthWorkoutActivityType.RUNNING_TREADMILL
          : HealthWorkoutActivityType.RUNNING;
    }
    if (n.contains('indoor cycling') ||
        n.contains('stationary bike') ||
        n.contains('assault bike') ||
        n.contains('air bike') ||
        n.contains('spin bike')) {
      return Platform.isAndroid
          ? HealthWorkoutActivityType.BIKING_STATIONARY
          : HealthWorkoutActivityType.BIKING;
    }
    if (n.contains('outdoor cycling') ||
        n.contains('cycle') ||
        n.contains('bike') ||
        n.contains('cycling')) {
      return HealthWorkoutActivityType.BIKING;
    }
    if (n.contains('jump rope') || n.contains('skip rope')) {
      return HealthWorkoutActivityType.JUMP_ROPE;
    }
    if (n.contains('battling rope') || n.contains('battle rope')) {
      return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
    }
    if (n.contains('boxing')) {
      return HealthWorkoutActivityType.BOXING;
    }
    if (n.contains('kickbox')) {
      return HealthWorkoutActivityType.KICKBOXING;
    }
    if (n.contains('skating') || n.contains('skater')) {
      return HealthWorkoutActivityType.SKATING;
    }
    if (n.contains('row')) {
      return Platform.isAndroid
          ? HealthWorkoutActivityType.ROWING_MACHINE
          : HealthWorkoutActivityType.ROWING;
    }
    if (n.contains('stair')) {
      return Platform.isAndroid
          ? HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE
          : HealthWorkoutActivityType.STAIR_CLIMBING;
    }
    if (n.contains('swim')) {
      return HealthWorkoutActivityType.SWIMMING;
    }
    if (n.contains('walk')) {
      return HealthWorkoutActivityType.WALKING;
    }
    if (n.contains('run') || n.contains('jog')) {
      return HealthWorkoutActivityType.RUNNING;
    }
    if (isCardio) {
      return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
    }
    return _defaultActivityType();
  }

  HealthWorkoutActivityType _defaultActivityType() {
    if (Platform.isAndroid) {
      return HealthWorkoutActivityType.STRENGTH_TRAINING;
    }
    return HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING;
  }

  Future<bool> _writeWorkout({
    required HealthWorkoutActivityType type,
    required DateTime start,
    required DateTime end,
    required String title,
    int? calories,
    int? distanceMeters,
    String? workoutBrandName,
    bool? isIndoorWorkout,
    String? syncIdentifier,
    int? syncVersion,
  }) async {
    if (Platform.isIOS) {
      final iosWritten = await _writeWorkoutWithMetadataIOS(
        type: type,
        start: start,
        end: end,
        title: title,
        calories: calories,
        distanceMeters: distanceMeters,
        workoutBrandName: workoutBrandName,
        isIndoorWorkout: isIndoorWorkout,
        syncIdentifier: syncIdentifier,
        syncVersion: syncVersion,
      );
      if (iosWritten == true) {
        return true;
      }
    }
    return _health.writeWorkoutData(
      activityType: type,
      start: start,
      end: end,
      totalEnergyBurned: calories,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      totalDistance: distanceMeters,
      totalDistanceUnit: HealthDataUnit.METER,
      title: title,
      recordingMethod: RecordingMethod.manual,
    );
  }

  String _externalWorkoutUuid({
    required DateTime start,
    required DateTime end,
    required String title,
  }) => '${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}_$title';

  HealthWorkoutActivityType? _extractActivityType(HealthDataPoint point) {
    final v = point.value;
    if (v is WorkoutHealthValue) return v.workoutActivityType;
    final summaryType = point.workoutSummary?.workoutType;
    if (summaryType == null || summaryType.isEmpty) return null;
    try {
      return HealthWorkoutActivityType.values.firstWhere(
        (e) => e.name == summaryType,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isSameWorkoutByTime({
    required DateTime aStart,
    required DateTime aEnd,
    required DateTime bStart,
    required DateTime bEnd,
  }) {
    final startDelta = aStart.difference(bStart).inSeconds.abs();
    final endDelta = aEnd.difference(bEnd).inSeconds.abs();
    return startDelta <= _dedupeWindow.inSeconds &&
        endDelta <= _dedupeWindow.inSeconds;
  }

  String? _metadataString(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<bool> _workoutAlreadyExists({
    required DateTime start,
    required DateTime end,
    required HealthWorkoutActivityType type,
    required String title,
  }) async {
    final safeEnd = end.isAfter(start)
        ? end
        : start.add(const Duration(seconds: 1));
    final queryStart = start.subtract(const Duration(minutes: 5));
    final queryEnd = safeEnd.add(const Duration(minutes: 5));
    final targetUuid = _externalWorkoutUuid(
      start: start,
      end: safeEnd,
      title: title,
    );

    try {
      final samples = await _health.getHealthDataFromTypes(
        startTime: queryStart,
        endTime: queryEnd,
        types: const [HealthDataType.WORKOUT],
      );
      for (final point in samples.where(
        (e) => e.type == HealthDataType.WORKOUT,
      )) {
        final metadata = point.metadata;
        final extUuid =
            _metadataString(metadata, 'HKExternalUUID') ??
            _metadataString(metadata, 'TAQA_CLIENT_ID_WORKOUT_METADATA_KEY');
        if (extUuid != null && extUuid == targetUuid) {
          return true;
        }

        final existingType = _extractActivityType(point);
        final typeMatches = existingType == null || existingType == type;
        if (!typeMatches) continue;

        if (_isSameWorkoutByTime(
          aStart: point.dateFrom,
          aEnd: point.dateTo,
          bStart: start,
          bEnd: safeEnd,
        )) {
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('WorkoutHealthSyncService: dedupe lookup failed: $e');
      }
    }

    return false;
  }

  Future<bool?> _writeWorkoutWithMetadataIOS({
    required HealthWorkoutActivityType type,
    required DateTime start,
    required DateTime end,
    required String title,
    int? calories,
    int? distanceMeters,
    String? workoutBrandName,
    bool? isIndoorWorkout,
    String? syncIdentifier,
    int? syncVersion,
  }) async {
    if (!Platform.isIOS) return null;
    try {
      final result = await _iosWorkoutMetadataChannel
          .invokeMethod<bool>('writeWorkoutWithMetadata', <String, dynamic>{
            'activityType': type.name,
            'startTime': start.millisecondsSinceEpoch,
            'endTime': end.millisecondsSinceEpoch,
            'totalEnergyBurned': calories,
            'totalEnergyBurnedUnit': HealthDataUnit.KILOCALORIE.name,
            'totalDistance': distanceMeters,
            'totalDistanceUnit': HealthDataUnit.METER.name,
            'title': title,
            'workoutBrandName': workoutBrandName,
            'isIndoorWorkout': isIndoorWorkout,
            'externalUuid': _externalWorkoutUuid(
              start: start,
              end: end,
              title: title,
            ),
            'syncIdentifier': syncIdentifier,
            'syncVersion': syncVersion,
          });
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print(
          'WorkoutHealthSyncService: iOS metadata workout write failed: $e',
        );
      }
      return null;
    }
  }

  Future<void> _writeStepsSample({
    required int stepsCount,
    required DateTime start,
    required DateTime end,
  }) async {
    if (stepsCount <= 0) return;
    try {
      await _health.writeHealthData(
        value: stepsCount.toDouble(),
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: end,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (_) {
      // Ignore step sample failures; workout write may still be valid.
    }
  }

  Future<WorkoutSessionWriteResult> writeWorkoutSessionWithStatus({
    required DateTime start,
    required DateTime end,
    String title = 'TAQA Workout',
    HealthWorkoutActivityType? activityType,
    String? exerciseName,
    bool isCardio = false,
    int? activeCaloriesKcal,
    int? totalDistanceMeters,
    int? stepsCount,
    String? workoutBrandName,
    bool? isIndoorWorkout,
    String? dedupeSignature,
    bool verifyHealthIfCachedDedupeSignature = false,
    String? syncIdentifier,
    int? syncVersion,
  }) async {
    final granted = await ConsentManager.requestUnifiedHealthPermissionsJIT();
    if (!granted) {
      if (kDebugMode) {
        print('WorkoutHealthSyncService: workout permission not granted.');
      }
      return WorkoutSessionWriteResult.failed;
    }

    return _writeWorkoutSessionAuthorizedWithStatus(
      start: start,
      end: end,
      title: title,
      activityType: activityType,
      exerciseName: exerciseName,
      isCardio: isCardio,
      activeCaloriesKcal: activeCaloriesKcal,
      totalDistanceMeters: totalDistanceMeters,
      stepsCount: stepsCount,
      workoutBrandName: workoutBrandName,
      isIndoorWorkout: isIndoorWorkout,
      dedupeSignature: dedupeSignature,
      verifyHealthIfCachedDedupeSignature: verifyHealthIfCachedDedupeSignature,
      syncIdentifier: syncIdentifier,
      syncVersion: syncVersion,
    );
  }

  Future<bool> writeWorkoutSession({
    required DateTime start,
    required DateTime end,
    String title = 'TAQA Workout',
    HealthWorkoutActivityType? activityType,
    String? exerciseName,
    bool isCardio = false,
    int? activeCaloriesKcal,
    int? totalDistanceMeters,
    int? stepsCount,
    String? workoutBrandName,
    bool? isIndoorWorkout,
    String? dedupeSignature,
    bool verifyHealthIfCachedDedupeSignature = false,
    String? syncIdentifier,
    int? syncVersion,
  }) async {
    final result = await writeWorkoutSessionWithStatus(
      start: start,
      end: end,
      title: title,
      activityType: activityType,
      exerciseName: exerciseName,
      isCardio: isCardio,
      activeCaloriesKcal: activeCaloriesKcal,
      totalDistanceMeters: totalDistanceMeters,
      stepsCount: stepsCount,
      workoutBrandName: workoutBrandName,
      isIndoorWorkout: isIndoorWorkout,
      dedupeSignature: dedupeSignature,
      verifyHealthIfCachedDedupeSignature: verifyHealthIfCachedDedupeSignature,
      syncIdentifier: syncIdentifier,
      syncVersion: syncVersion,
    );
    return result.isSuccess;
  }

  Future<WorkoutSessionWriteResult> _writeWorkoutSessionAuthorizedWithStatus({
    required DateTime start,
    required DateTime end,
    required String title,
    HealthWorkoutActivityType? activityType,
    String? exerciseName,
    required bool isCardio,
    int? activeCaloriesKcal,
    int? totalDistanceMeters,
    int? stepsCount,
    String? workoutBrandName,
    bool? isIndoorWorkout,
    String? dedupeSignature,
    bool verifyHealthIfCachedDedupeSignature = false,
    String? syncIdentifier,
    int? syncVersion,
  }) async {
    final safeEnd = end.isAfter(start)
        ? end
        : start.add(const Duration(seconds: 1));
    final durationSeconds = safeEnd.difference(start).inSeconds;
    final type =
        activityType ??
        _activityTypeFromName(exerciseName ?? title, isCardio: isCardio);
    final signature = _normalizeSignaturePart(
      _workoutDedupeSignature(
        start: start,
        end: safeEnd,
        type: type,
        title: title,
        custom: dedupeSignature,
      ),
    );

    try {
      final signatureKnown = await _isDedupeSignatureKnown(signature);
      if (signatureKnown && !verifyHealthIfCachedDedupeSignature) {
        if (kDebugMode) {
          print('WorkoutHealthSyncService: skipped duplicate (local cache).');
        }
        return WorkoutSessionWriteResult.skippedDuplicate;
      }

      final exists = await _workoutAlreadyExists(
        start: start,
        end: safeEnd,
        type: type,
        title: title,
      );
      if (exists) {
        await _rememberDedupeSignature(signature);
        if (kDebugMode) {
          print('WorkoutHealthSyncService: skipped duplicate workout write.');
        }
        return WorkoutSessionWriteResult.skippedDuplicate;
      }
      if (signatureKnown && verifyHealthIfCachedDedupeSignature && kDebugMode) {
        print(
          'WorkoutHealthSyncService: signature cached locally but missing in Health; rewriting.',
        );
      }
      final weightKg =
          await _loadWeightKg() ?? TrainingCalorieEstimator.defaultWeightKg;
      final calories =
          activeCaloriesKcal ??
          TrainingCalorieEstimator.estimateCaloriesKcal(
            durationSeconds: durationSeconds,
            isCardio: isCardio,
            weightKg: weightKg,
          );
      final distance = (totalDistanceMeters != null && totalDistanceMeters > 0)
          ? totalDistanceMeters
          : null;
      final enriched = await _writeWorkout(
        type: type,
        start: start,
        end: safeEnd,
        title: title,
        calories: calories,
        distanceMeters: distance,
        workoutBrandName: workoutBrandName,
        isIndoorWorkout: isIndoorWorkout,
        syncIdentifier: syncIdentifier,
        syncVersion: syncVersion,
      );
      if (enriched) {
        if (stepsCount != null && stepsCount > 0) {
          await _writeStepsSample(
            stepsCount: stepsCount,
            start: start,
            end: safeEnd,
          );
        }
        await _rememberDedupeSignature(signature);
        return WorkoutSessionWriteResult.written;
      }
      // If enriched write fails (commonly due extra permission scopes), retry bare workout.
      final bare = await _writeWorkout(
        type: type,
        start: start,
        end: safeEnd,
        title: title,
        calories: null,
        distanceMeters: null,
        workoutBrandName: workoutBrandName,
        isIndoorWorkout: isIndoorWorkout,
        syncIdentifier: syncIdentifier,
        syncVersion: syncVersion,
      );
      if (bare && stepsCount != null && stepsCount > 0) {
        await _writeStepsSample(
          stepsCount: stepsCount,
          start: start,
          end: safeEnd,
        );
      }
      if (bare) {
        await _rememberDedupeSignature(signature);
        return WorkoutSessionWriteResult.written;
      }
      return WorkoutSessionWriteResult.failed;
    } catch (e) {
      if (kDebugMode) {
        print('WorkoutHealthSyncService: write failed: $e');
      }
      try {
        final bare = await _writeWorkout(
          type: type,
          start: start,
          end: safeEnd,
          title: title,
          calories: null,
          distanceMeters: null,
          workoutBrandName: workoutBrandName,
          isIndoorWorkout: isIndoorWorkout,
          syncIdentifier: syncIdentifier,
          syncVersion: syncVersion,
        );
        if (bare && stepsCount != null && stepsCount > 0) {
          await _writeStepsSample(
            stepsCount: stepsCount,
            start: start,
            end: safeEnd,
          );
        }
        if (bare) {
          await _rememberDedupeSignature(signature);
          return WorkoutSessionWriteResult.written;
        }
        return WorkoutSessionWriteResult.failed;
      } catch (_) {
        return WorkoutSessionWriteResult.failed;
      }
    }
  }

  Map<String, dynamic>? _extractComplianceMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int _positiveInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value > 0 ? value : 0;
    if (value is num) {
      final v = value.toInt();
      return v > 0 ? v : 0;
    }
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null || parsed <= 0) return 0;
    return parsed;
  }

  int _resolvedCount(dynamic value, {required int fallback}) {
    final parsed = _positiveInt(value);
    return parsed > 0 ? parsed : fallback;
  }

  bool _hasClockTime(DateTime dt) {
    return dt.hour != 0 ||
        dt.minute != 0 ||
        dt.second != 0 ||
        dt.millisecond != 0 ||
        dt.microsecond != 0;
  }

  DateTime? _parseTimestampWithClock(dynamic value) {
    if (value == null) return null;
    final dt = _parseBackendDateTime(value);
    if (dt == null || !_hasClockTime(dt)) return null;
    final utc = dt.toUtc();
    final isMidnightUtc =
        utc.hour == 0 &&
        utc.minute == 0 &&
        utc.second == 0 &&
        utc.millisecond == 0 &&
        utc.microsecond == 0;
    return isMidnightUtc ? null : dt;
  }

  DateTime? _extractLatestTrainingExerciseTimestamp(Map<String, dynamic> ex) {
    DateTime? best;
    void consider(DateTime? dt) {
      if (dt == null) return;
      if (best == null || dt.isAfter(best!)) {
        best = dt;
      }
    }

    final complianceMaps = <Map<String, dynamic>?>[
      _extractComplianceMap(ex['program_compliance']),
      _extractComplianceMap(ex['compliance']),
    ];
    for (final c in complianceMaps) {
      if (c == null) continue;
      consider(_parseTimestampWithClock(c['logged_at']));
      consider(_parseTimestampWithClock(c['performed_at']));
      consider(_parseTimestampWithClock(c['last_performed_at']));
      consider(_parseTimestampWithClock(c['ended_at']));
      consider(_parseTimestampWithClock(c['end_time']));
      consider(_parseTimestampWithClock(c['finished_at']));
      consider(_parseTimestampWithClock(c['completed_at']));
      consider(_parseTimestampWithClock(c['updated_at']));
    }

    consider(_parseTimestampWithClock(ex['logged_at']));
    consider(_parseTimestampWithClock(ex['performed_at']));
    consider(_parseTimestampWithClock(ex['last_performed_at']));
    consider(_parseTimestampWithClock(ex['ended_at']));
    consider(_parseTimestampWithClock(ex['end_time']));
    consider(_parseTimestampWithClock(ex['finished_at']));
    consider(_parseTimestampWithClock(ex['completed_at']));
    consider(_parseTimestampWithClock(ex['updated_at']));
    return best;
  }

  DateTime _seedTrainingHistorySessionEnd({
    required DateTime day,
    required String seedKey,
  }) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final base = DateTime(
      normalizedDay.year,
      normalizedDay.month,
      normalizedDay.day,
      18,
      0,
    );
    final minuteOffset = _stableHash(seedKey) % 180;
    return base.add(Duration(minutes: minuteOffset));
  }

  int _estimateTrainingHistoryDurationSeconds({
    required List<Map<String, dynamic>> completedExercises,
    required int completedCount,
  }) {
    var totalSeconds = 0;
    for (final ex in completedExercises) {
      var exSeconds = 0;
      final compliance =
          _extractComplianceMap(ex['program_compliance']) ??
          _extractComplianceMap(ex['compliance']);
      exSeconds += _positiveInt(compliance?['performed_time_seconds']);
      exSeconds += _positiveInt(ex['duration_seconds']);
      exSeconds += _positiveInt(ex['performed_time_seconds']);
      exSeconds += _positiveInt(ex['time_seconds']);
      exSeconds += _positiveInt(ex['elapsed_seconds']);
      if (exSeconds <= 0) {
        final sets = _positiveInt(
          compliance?['performed_sets'] ?? ex['performed_sets'] ?? ex['sets'],
        );
        final reps = _positiveInt(
          compliance?['performed_reps'] ?? ex['performed_reps'] ?? ex['reps'],
        );
        if (sets > 0 && reps > 0) {
          exSeconds += (sets * reps * 3);
        }
      }
      totalSeconds += exSeconds;
    }

    final count = completedCount > 0
        ? completedCount
        : completedExercises.length;
    if (totalSeconds <= 0) {
      final estimated = count * 300;
      return estimated.clamp(600, 14400);
    }
    final minimumFromCount = count * 90;
    final normalized = totalSeconds < minimumFromCount
        ? minimumFromCount
        : totalSeconds;
    return normalized.clamp(300, 14400);
  }

  DateTime _resolveTrainingHistorySessionEnd({
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> completedExercises,
    required int index,
  }) {
    DateTime? best;
    for (final ex in completedExercises) {
      final ts = _extractLatestTrainingExerciseTimestamp(ex);
      if (ts == null) continue;
      if (best == null || ts.isAfter(best)) {
        best = ts;
      }
    }
    if (best != null) return best;

    final itemWithClock =
        _parseTimestampWithClock(item['latest_date']) ??
        _parseTimestampWithClock(item['entry_date']) ??
        _parseTimestampWithClock(item['updated_at']) ??
        _parseTimestampWithClock(item['created_at']);
    if (itemWithClock != null) return itemWithClock;

    final baseDay =
        _parseBackendDateTime(item['latest_date']) ??
        _parseBackendDateTime(item['entry_date']) ??
        _parseBackendDateTime(item['week_start']) ??
        DateTime.now();
    final seedKey =
        (item['day_key'] ?? item['training_day_id'] ?? item['day_id'] ?? index)
            .toString();
    return _seedTrainingHistorySessionEnd(day: baseDay, seedKey: seedKey);
  }

  String _trainingHistoryDedupeSignature({
    required Map<String, dynamic> item,
    required String label,
    required DateTime fallbackDay,
  }) {
    final day =
        _parseBackendDateTime(item['entry_date']) ??
        _parseBackendDateTime(item['latest_date']) ??
        _parseBackendDateTime(item['week_start']) ??
        _parseBackendDateTime(item['created_at']) ??
        _parseBackendDateTime(item['updated_at']) ??
        fallbackDay;
    final trainingDayId = _toInt(item['training_day_id']);
    final dayId = trainingDayId > 0 ? trainingDayId : _toInt(item['day_id']);
    final dayKey = item['day_key']?.toString();
    return buildTrainingHistoryDayDedupeSignature(
      day: day,
      trainingDayId: dayId > 0 ? dayId : null,
      dayKey: dayKey,
      label: label,
    );
  }

  Future<Map<String, int>> writeTrainingHistorySessions({
    required List<Map<String, dynamic>> historyItems,
    bool verifyHealthIfCachedDedupeSignature = false,
  }) async {
    final granted = await ConsentManager.requestUnifiedHealthPermissionsJIT();
    if (!granted) {
      return {
        'total': historyItems.length,
        'written': 0,
        'skipped': 0,
        'failed': historyItems.length,
      };
    }

    int total = 0;
    int written = 0;
    int skipped = 0;
    int failed = 0;

    for (int i = 0; i < historyItems.length; i++) {
      final item = historyItems[i];
      final completedRaw = item['completed_exercises'];
      final completedExercises = completedRaw is List
          ? completedRaw
                .map(
                  (e) => e is Map<String, dynamic>
                      ? e
                      : (e is Map ? Map<String, dynamic>.from(e) : null),
                )
                .whereType<Map<String, dynamic>>()
                .toList()
          : const <Map<String, dynamic>>[];
      final completedCount = _resolvedCount(
        item['completed_count'],
        fallback: completedExercises.length,
      );
      if (completedExercises.isEmpty || completedCount <= 0) {
        continue;
      }

      final label = (item['label'] ?? item['day_label'] ?? 'Training day')
          .toString()
          .trim();
      final title = label.isEmpty ? 'TAQA Strength Workout' : '$label Workout';
      final durationSeconds = _estimateTrainingHistoryDurationSeconds(
        completedExercises: completedExercises,
        completedCount: completedCount,
      );
      final end = _resolveTrainingHistorySessionEnd(
        item: item,
        completedExercises: completedExercises,
        index: i,
      );
      final start = end.subtract(Duration(seconds: durationSeconds));
      final dedupeSignature = _trainingHistoryDedupeSignature(
        item: item,
        label: label,
        fallbackDay: end,
      );
      total += 1;

      final result = await _writeWorkoutSessionAuthorizedWithStatus(
        start: start,
        end: end,
        title: title,
        exerciseName: title,
        isCardio: false,
        workoutBrandName: label.isEmpty ? null : label,
        isIndoorWorkout: true,
        dedupeSignature: dedupeSignature,
        verifyHealthIfCachedDedupeSignature:
            verifyHealthIfCachedDedupeSignature,
      );
      switch (result.status) {
        case WorkoutSessionWriteStatus.written:
          written += 1;
          break;
        case WorkoutSessionWriteStatus.skippedDuplicate:
          skipped += 1;
          break;
        case WorkoutSessionWriteStatus.failed:
          failed += 1;
          break;
      }
    }

    return {
      'total': total,
      'written': written,
      'skipped': skipped,
      'failed': failed,
    };
  }

  Future<Map<String, int>> writeCardioHistorySessions({
    required List<Map<String, dynamic>> sessions,
    bool verifyHealthIfCachedDedupeSignature = false,
  }) async {
    final granted = await ConsentManager.requestUnifiedHealthPermissionsJIT();
    if (!granted) {
      return {
        'total': sessions.length,
        'written': 0,
        'skipped': 0,
        'failed': sessions.length,
      };
    }

    int written = 0;
    int skipped = 0;
    int failed = 0;

    for (int i = 0; i < sessions.length; i++) {
      final item = sessions[i];
      final durationSeconds = _toInt(item['duration_seconds']).clamp(1, 86400);
      final nameRaw =
          (item['exercise_name'] ?? item['name'] ?? 'Cardio Session')
              .toString()
              .trim();
      final title = nameRaw.isEmpty ? 'Cardio Session' : nameRaw;
      final distanceKm = _toDouble(item['distance_km']) ?? 0;
      final distanceMeters = distanceKm > 0
          ? (distanceKm * 1000).round()
          : null;
      final steps = _toInt(item['steps']);
      final stepsCount = steps > 0 ? steps : null;
      final dedupeSignature = _cardioHistoryDedupeSignature(
        item: item,
        title: title,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        stepsCount: stepsCount,
      );

      final endFromApi =
          _parseBackendDateTime(item['ended_at']) ??
          _parseBackendDateTime(item['finished_at']) ??
          _parseBackendDateTime(item['end_time']);
      final startFromApi =
          _parseBackendDateTime(item['started_at']) ??
          _parseBackendDateTime(item['start_time']);
      final entryDate = _parseBackendDateTime(item['entry_date']);

      DateTime start;
      DateTime end;
      if (startFromApi != null &&
          endFromApi != null &&
          endFromApi.isAfter(startFromApi)) {
        start = startFromApi;
        end = endFromApi;
      } else if (startFromApi != null) {
        start = startFromApi;
        end = start.add(Duration(seconds: durationSeconds));
      } else if (endFromApi != null) {
        end = endFromApi;
        start = end.subtract(Duration(seconds: durationSeconds));
      } else {
        final base =
            entryDate ??
            _parseBackendDateTime(item['created_at']) ??
            _parseBackendDateTime(item['updated_at']) ??
            DateTime(2024, 1, 1);
        final seed = _seedCardioSessionEnd(
          baseDay: base,
          seedKey: dedupeSignature,
        );
        end = seed;
        start = end.subtract(Duration(seconds: durationSeconds));
      }

      final result = await _writeWorkoutSessionAuthorizedWithStatus(
        start: start,
        end: end,
        title: title,
        exerciseName: title,
        isCardio: true,
        totalDistanceMeters: distanceMeters,
        stepsCount: stepsCount,
        dedupeSignature: dedupeSignature,
        verifyHealthIfCachedDedupeSignature:
            verifyHealthIfCachedDedupeSignature,
      );
      switch (result.status) {
        case WorkoutSessionWriteStatus.written:
          written += 1;
          break;
        case WorkoutSessionWriteStatus.skippedDuplicate:
          skipped += 1;
          break;
        case WorkoutSessionWriteStatus.failed:
          failed += 1;
          break;
      }
    }

    return {
      'total': sessions.length,
      'written': written,
      'skipped': skipped,
      'failed': failed,
    };
  }
}
