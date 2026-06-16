import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'training_program_storage.dart';
import 'training_progress_storage.dart';
import 'training_reset_coordinator.dart';
import '../core/feedback_questions_storage.dart';

class TrainingApiException implements Exception {
  final int statusCode;
  final String detail;

  TrainingApiException(this.statusCode, this.detail);

  bool get isRetryable =>
      statusCode >= 500 || statusCode == 408 || statusCode == 429;

  @override
  String toString() => detail;
}

class TrainingGenerationInProgressException implements Exception {
  final String detail;

  TrainingGenerationInProgressException([
    this.detail = 'Training generation is in progress',
  ]);

  @override
  String toString() => detail;
}

class TrainingPlanChangeEvent {
  final int eventId;
  final int? coachUserId;
  final int? sourceProgramId;
  final int? targetProgramId;
  final String eventType;
  final String? fromPlanSource;
  final String? toPlanSource;
  final String summary;
  final List<Map<String, dynamic>> details;
  final String? createdAt;
  final String? clientSeenAt;
  final bool isNew;

  const TrainingPlanChangeEvent({
    required this.eventId,
    required this.coachUserId,
    required this.sourceProgramId,
    required this.targetProgramId,
    required this.eventType,
    required this.fromPlanSource,
    required this.toPlanSource,
    required this.summary,
    required this.details,
    required this.createdAt,
    required this.clientSeenAt,
    required this.isNew,
  });

  factory TrainingPlanChangeEvent.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    final parsedDetails = rawDetails is List
        ? rawDetails
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return TrainingPlanChangeEvent(
      eventId: json['event_id'] is int
          ? json['event_id'] as int
          : int.tryParse('${json['event_id']}') ?? 0,
      coachUserId: json['coach_user_id'] is int
          ? json['coach_user_id'] as int
          : int.tryParse('${json['coach_user_id']}'),
      sourceProgramId: json['source_program_id'] is int
          ? json['source_program_id'] as int
          : int.tryParse('${json['source_program_id']}'),
      targetProgramId: json['target_program_id'] is int
          ? json['target_program_id'] as int
          : int.tryParse('${json['target_program_id']}'),
      eventType: (json['event_type'] ?? '').toString(),
      fromPlanSource: (json['from_plan_source'] ?? '').toString().trim().isEmpty
          ? null
          : (json['from_plan_source'] ?? '').toString().trim(),
      toPlanSource: (json['to_plan_source'] ?? '').toString().trim().isEmpty
          ? null
          : (json['to_plan_source'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString(),
      details: parsedDetails,
      createdAt: (json['created_at'] ?? '').toString().trim().isEmpty
          ? null
          : (json['created_at'] ?? '').toString(),
      clientSeenAt: (json['client_seen_at'] ?? '').toString().trim().isEmpty
          ? null
          : (json['client_seen_at'] ?? '').toString(),
      isNew: json['is_new'] == true,
    );
  }
}

class TrainingService {
  static String baseUrl = ApiConfig.baseUrl;
  static final Map<String, ImageProvider> _gifProviders = {};
  static final Set<String> _gifEverLoaded = <String>{};
  static final Map<String, ImageInfo> _gifFrames = {};
  static List<Map<String, dynamic>> _trainingHistorySnapshot =
      const <Map<String, dynamic>>[];
  static int? _trainingHistorySnapshotUserId;
  static int _trainingHistorySnapshotLimitDays = 0;
  static DateTime? _trainingHistorySnapshotFetchedAtUtc;
  static Future<void>? _trainingHistorySnapshotInFlight;

  static void _recordServerClock(http.BaseResponse response) {
    unawaited(
      TrainingResetCoordinator.captureServerTimeFromHeaders(response.headers),
    );
  }

  /// Use full [animationUrl] (signed GCS). Ignore [animationRelPath] to avoid
  /// local /static fallbacks; return empty string if unavailable.
  static String animationImageUrl(
    String? animationUrl,
    String? _animationRelPath,
  ) {
    String normalizeAbsolute(String raw) {
      final v = raw.trim();
      if (v.isEmpty) return '';
      if (v.startsWith('http://') || v.startsWith('https://')) return v;
      if (v.startsWith('//')) return "https:$v";
      return '';
    }

    final direct = normalizeAbsolute(animationUrl ?? '');
    if (direct.isNotEmpty) return direct;
    return '';
  }

  static String _gifKey(String url, int? cacheWidth, int? cacheHeight) {
    final baseKey = _cacheKeyForUrl(url);
    final w = cacheWidth?.toString() ?? '';
    final h = cacheHeight?.toString() ?? '';
    return "$baseKey|$w|$h";
  }

  static String _cacheKeyForUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery && !uri.hasFragment) return url;
      return uri.replace(query: '', fragment: '').toString();
    } catch (_) {
      return url;
    }
  }

  static ImageProvider gifProvider(
    String url, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final key = _gifKey(url, cacheWidth, cacheHeight);
    final existing = _gifProviders[key];
    if (existing != null) return existing;

    final cacheKey = _cacheKeyForUrl(url);
    ImageProvider provider = CachedNetworkImageProvider(
      url,
      cacheKey: cacheKey,
    );
    if (cacheWidth != null || cacheHeight != null) {
      provider = ResizeImage(provider, width: cacheWidth, height: cacheHeight);
    }
    _gifProviders[key] = provider;
    return provider;
  }

  static bool gifEverLoaded(String url) => _gifEverLoaded.contains(url);

  static void markGifLoaded(String url) {
    _gifEverLoaded.add(url);
  }

  static ImageInfo? getGifFrame(
    String url, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final key = _gifKey(url, cacheWidth, cacheHeight);
    return _gifFrames[key];
  }

  static void cacheGifFrame(
    String url,
    ImageInfo info, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final key = _gifKey(url, cacheWidth, cacheHeight);
    _gifFrames[key] = info;
  }

  static Future<void> warmGif(
    BuildContext context,
    String url, {
    int? cacheWidth,
    int? cacheHeight,
  }) async {
    final provider = gifProvider(
      url,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
    await precacheImage(provider, context);
  }

  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool? _toBoolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == 'active' ||
        normalized == 'open') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'n' ||
        normalized == 'inactive' ||
        normalized == 'closed') {
      return false;
    }
    return null;
  }

  static bool _isNoActiveSessionMessage(Map<String, dynamic> payload) {
    final message = [
      payload['status'],
      payload['state'],
      payload['message'],
      payload['detail'],
      payload['error'],
    ].where((e) => e != null).map((e) => e.toString().toLowerCase()).join(' ');
    if (message.isEmpty) return false;
    return message.contains('no active session') ||
        message.contains('no current session') ||
        message.contains('session not found') ||
        message.contains('finished') ||
        message.contains('completed') ||
        message.contains('closed') ||
        message.contains('ended');
  }

  static Map<String, dynamic> _normalizeTrainingProgressPayload(
    Map<String, dynamic> payload,
  ) {
    final completed =
        payload['completed'] ??
        payload['completed_days'] ??
        payload['days_completed'] ??
        payload['done'];
    final total =
        payload['total'] ??
        payload['total_days'] ??
        payload['days_total'] ??
        payload['planned_days'];
    final mode = payload['program_mode'] ?? payload['mode'];
    return {
      ...payload,
      'completed': _toInt(completed),
      'total': _toInt(total),
      'program_mode': mode?.toString(),
    };
  }

  static List<Uri> _trainingProgressCandidates({
    required int userId,
    required String startParam,
    required String endParam,
  }) {
    return [
      Uri.parse(
        '$baseUrl/training/session/progress/$userId?start=$startParam&end=$endParam',
      ),
      Uri.parse(
        '$baseUrl/training/sessions/progress/$userId?start=$startParam&end=$endParam',
      ),
      Uri.parse(
        '$baseUrl/training/workout-sessions/progress/$userId?start=$startParam&end=$endParam',
      ),
      Uri.parse(
        '$baseUrl/training/workout_sessions/progress/$userId?start=$startParam&end=$endParam',
      ),
      // Backward compatibility for environments that still expose the legacy route.
      Uri.parse(
        '$baseUrl/training/progress/$userId?start=$startParam&end=$endParam',
      ),
    ];
  }

  static Future<Map<String, dynamic>?> _fetchTrainingProgressCandidate({
    required Uri url,
    required Map<String, String> headers,
  }) async {
    final response = await http.get(url, headers: headers);
    _recordServerClock(response);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception("Failed to load training progress");
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw Exception("Invalid training progress response");
    }
    return _normalizeTrainingProgressPayload(
      Map<String, dynamic>.from(decoded),
    );
  }

  static Map<String, dynamic> _decodeMapBody(String rawBody) {
    if (rawBody.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(rawBody);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static String _generationStatusFromPayload(Map<String, dynamic> payload) {
    final top = payload['status']?.toString().trim().toLowerCase();
    if (top != null && top.isNotEmpty) return top;
    final nested = payload['generation'];
    if (nested is Map) {
      final nestedStatus = nested['status']?.toString().trim().toLowerCase();
      if (nestedStatus != null && nestedStatus.isNotEmpty) return nestedStatus;
    }
    return 'idle';
  }

  static String _generationErrorFromPayload(Map<String, dynamic> payload) {
    final direct = payload['error']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final detail = payload['detail']?.toString();
    if (detail != null && detail.trim().isNotEmpty) return detail.trim();
    final nested = payload['generation'];
    if (nested is Map) {
      final nestedError = nested['error']?.toString();
      if (nestedError != null && nestedError.trim().isNotEmpty) {
        return nestedError.trim();
      }
    }
    return 'Training generation failed';
  }

  static Future<Map<String, dynamic>> generateProgram(int userId) async {
    final url = Uri.parse('$baseUrl/training/generate/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);
    _recordServerClock(response);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode == 200 || response.statusCode == 202) {
      return _decodeMapBody(response.body);
    }

    if (response.statusCode == 400) {
      final body = _decodeMapBody(response.body);
      throw Exception(body['detail'] ?? 'Training generation failed');
    }

    throw Exception('Unexpected error (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> fetchGenerationStatus(int userId) async {
    final url = Uri.parse('$baseUrl/training/generation/status/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    _recordServerClock(response);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to load training generation status');
    }
    return _decodeMapBody(response.body);
  }

  static Future<Map<String, dynamic>> waitForGenerationToComplete(
    int userId, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final statusPayload = await fetchGenerationStatus(userId);
      final status = _generationStatusFromPayload(statusPayload);
      if (status == 'succeeded') return statusPayload;
      if (status == 'failed') {
        throw Exception(_generationErrorFromPayload(statusPayload));
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Training generation timed out');
      }
      await Future.delayed(pollInterval);
    }
  }

  static Future<Map<String, dynamic>> fetchActiveProgram(int userId) async {
    final url = Uri.parse('$baseUrl/training/current/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    _recordServerClock(response);
    await AccountStorage.handle401(response.statusCode);

    if (response.statusCode == 202) {
      final body = _decodeMapBody(response.body);
      final detail =
          body['detail']?.toString() ??
          body['message']?.toString() ??
          'Training generation is in progress';
      throw TrainingGenerationInProgressException(detail);
    }

    if (response.statusCode != 200) {
      throw Exception("Failed to load program");
    }

    final program = json.decode(response.body) as Map<String, dynamic>;

    // Cache program locally for offline access
    await TrainingProgramStorage.saveProgram(program);
    await TrainingProgressStorage.syncProgram(program);

    return program;
  }

  static Future<Map<String, dynamic>> fetchTrainingProgress({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final startParam = _dateParam(start);
    final endParam = _dateParam(end);
    final headers = await AccountStorage.getAuthHeaders();
    final candidates = _trainingProgressCandidates(
      userId: userId,
      startParam: startParam,
      endParam: endParam,
    );
    for (final uri in candidates) {
      final progress = await _fetchTrainingProgressCandidate(
        url: uri,
        headers: headers,
      );
      if (progress != null) {
        return progress;
      }
    }
    throw Exception("Failed to load training progress");
  }

  /// Fetch program from cache (for offline use)
  static Future<Map<String, dynamic>?> fetchActiveProgramFromCache() async {
    final program = await TrainingProgramStorage.loadProgram();
    if (program != null) {
      await TrainingProgressStorage.syncProgram(program);
    }
    return program;
  }

  /// Start an exercise and (optionally) record entry_date (user local date) on backend.
  /// When entryDate is provided, backend can map date -> training_day_id for diet inference.
  static Future<void> startExercise(
    int programExerciseId, {
    DateTime? entryDate,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/start');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        if (entryDate != null) 'entry_date': _dateParam(entryDate),
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to start exercise");
    }
  }

  static Future<void> saveWeight(int programExerciseId, double weight) async {
    final url = Uri.parse('$baseUrl/training/exercise/weight');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        'weight_used': weight,
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<void> finishExercise({
    required int programExerciseId,
    int? sets,
    int? reps,
    int? rir,
    required int durationSeconds,
    DateTime? entryDate,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/finish');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        if (sets != null) 'performed_sets': sets,
        if (reps != null) 'performed_reps': reps,
        if (rir != null) 'performed_rir': rir,
        'performed_time_seconds': durationSeconds,
        if (entryDate != null) 'entry_date': _dateParam(entryDate),
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<List<Map<String, dynamic>>> fetchExerciseSets(
    int programExerciseId,
  ) async {
    final url = Uri.parse('$baseUrl/training/exercise/$programExerciseId/sets');
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load exercise sets");
    }
    final data = json.decode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) {
          int parseIndex(dynamic v) {
            if (v is int) return v;
            if (v is num) return v.toInt();
            if (v is String) return int.tryParse(v.trim()) ?? 0;
            return 0;
          }

          return parseIndex(
            a['set_index'],
          ).compareTo(parseIndex(b['set_index']));
        });
    }
    return const [];
  }

  static Future<Map<String, dynamic>> addExerciseSet({
    required int programExerciseId,
    bool cloneLast = true,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/set/add');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        'clone_last': cloneLast,
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to add set");
    }
    final data = json.decode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return const {"status": "added"};
  }

  static Future<Map<String, dynamic>> upsertExerciseSet({
    required int programExerciseId,
    required int setIndex,
    int? reps,
    int? rir,
    double? weightKg,
    bool? completed,
    int? performedTimeSeconds,
    int? restAfterSeconds,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/set/upsert');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final body = <String, dynamic>{
      'program_exercise_id': programExerciseId,
      'set_index': setIndex,
      if (reps != null) 'reps': reps,
      if (rir != null) 'rir': rir,
      if (weightKg != null) 'weight_kg': weightKg,
      if (completed != null) 'completed': completed,
      if (performedTimeSeconds != null)
        'performed_time_seconds': performedTimeSeconds,
      if (restAfterSeconds != null) 'rest_after_seconds': restAfterSeconds,
    };
    final res = await http.post(url, headers: headers, body: json.encode(body));
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to save set");
    }
    final data = json.decode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return const {"status": "saved"};
  }

  static Future<Map<String, dynamic>> deleteExerciseSet({
    required int programExerciseId,
    required int setIndex,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/set/delete');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        'set_index': setIndex,
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to delete set");
    }
    final data = json.decode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return const {"status": "deleted"};
  }

  static Future<Map<String, dynamic>> fetchCurrentSession() async {
    final url = Uri.parse('$baseUrl/training/session/current');
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load current session");
    }
    final data = json.decode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static Future<bool> hasActiveSession() async {
    try {
      final current = await fetchCurrentSession();
      if (current.isEmpty) return false;
      if (_isNoActiveSessionMessage(current)) return false;

      final activeFlag = _toBoolOrNull(
        current['is_active'] ??
            current['active'] ??
            current['session_active'] ??
            current['isOpen'],
      );
      if (activeFlag != null) return activeFlag;

      final sessionId = _toInt(current['session_id'] ?? current['id']);
      if (sessionId > 0) return true;

      final startedAt =
          current['started_at'] ??
          current['start_time'] ??
          current['startedAt'];
      if (startedAt != null && startedAt.toString().trim().isNotEmpty) {
        return true;
      }

      // If schema is unfamiliar but payload is non-empty, assume active
      // so we don't accidentally drop a needed finish call.
      return true;
    } catch (_) {
      // If backend check fails, keep retry behavior for queued session finish.
      return true;
    }
  }

  static Future<void> finishSession({required DateTime entryDate}) async {
    final url = Uri.parse('$baseUrl/training/session/finish');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({'entry_date': _dateParam(entryDate)}),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to finish session");
    }
  }

  /// Auto-close any open workout session older than [olderThanSeconds]
  /// (default 4h). Not scoped to today's entry_date, so it also cleans up
  /// abandoned sessions left open from previous days. Returns how many closed.
  static Future<int> finishStaleSessions({
    int olderThanSeconds = 4 * 60 * 60,
  }) async {
    final url = Uri.parse('$baseUrl/training/session/finish-stale');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({'older_than_seconds': olderThanSeconds}),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to finish stale sessions");
    }
    final data = json.decode(res.body);
    if (data is Map && data['closed'] is num) {
      return (data['closed'] as num).toInt();
    }
    return 0;
  }

  static Future<void> saveCardioSession({
    int? programExerciseId,
    int? exerciseId,
    required double distanceKm,
    required double avgPaceMinKm,
    required int durationSeconds,
    int? steps,
    double? inclinePercent,
    List<Map<String, dynamic>>? routePoints,
    DateTime? entryDate,
  }) async {
    final url = Uri.parse('$baseUrl/training/cardio/finish');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final body = <String, dynamic>{
      'distance_km': distanceKm,
      'avg_pace_min_km': avgPaceMinKm,
      'duration_seconds': durationSeconds,
    };
    if (steps != null) body['steps'] = steps;
    if (inclinePercent != null) body['incline_percent'] = inclinePercent;
    if (programExerciseId != null)
      body['program_exercise_id'] = programExerciseId;
    if (exerciseId != null) body['exercise_id'] = exerciseId;
    if (routePoints != null) body['route_points'] = routePoints;
    if (entryDate != null) body['entry_date'] = _dateParam(entryDate);
    final res = await http.post(url, headers: headers, body: json.encode(body));
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to save cardio session");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCardioHistory({
    required int userId,
    int limit = 100,
  }) async {
    final url = Uri.parse(
      '$baseUrl/training/cardio/history/$userId?limit=$limit',
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load cardio history");
    }
    final data = json.decode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  static Future<Map<String, dynamic>> fetchCardioHistoryDetail({
    required int userId,
    required int sessionId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/training/cardio/history/$userId/detail/$sessionId',
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load cardio history detail");
    }
    final data = json.decode(res.body);
    if (data is Map) {
      return Map<String, dynamic>.from(data as Map);
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> fetchCardioExercises() async {
    final url = Uri.parse('$baseUrl/training/cardio/exercises');
    final res = await http.get(url);
    _recordServerClock(res);
    if (res.statusCode != 200) {
      throw Exception("Failed to load cardio exercises");
    }
    final data = json.decode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  static Future<List<Map<String, dynamic>>> fetchTrainingHistory({
    required int userId,
    int limitDays = 540,
  }) async {
    final url = Uri.parse(
      '$baseUrl/training/history/$userId?limit_days=$limitDays',
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load training history");
    }
    final data = json.decode(res.body);
    if (data is List) {
      final rows = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _trainingHistorySnapshot = rows;
      _trainingHistorySnapshotUserId = userId;
      _trainingHistorySnapshotLimitDays = limitDays;
      _trainingHistorySnapshotFetchedAtUtc = DateTime.now().toUtc();
      return rows;
    }
    _trainingHistorySnapshot = const <Map<String, dynamic>>[];
    _trainingHistorySnapshotUserId = userId;
    _trainingHistorySnapshotLimitDays = limitDays;
    _trainingHistorySnapshotFetchedAtUtc = DateTime.now().toUtc();
    return const [];
  }

  static Future<List<Map<String, dynamic>>?> readCachedTrainingHistory({
    required int userId,
    int minLimitDays = 1,
  }) async {
    if (_trainingHistorySnapshotUserId != userId) return null;
    if (_trainingHistorySnapshotLimitDays < minLimitDays) return null;
    if (_trainingHistorySnapshot.isEmpty) return const <Map<String, dynamic>>[];
    return _trainingHistorySnapshot
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Future<void> prefetchTrainingHistorySnapshot({
    int limitDays = 42,
    bool force = false,
    Duration maxAge = const Duration(minutes: 20),
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) return;
    final now = DateTime.now().toUtc();
    final hasFreshEnoughCache =
        !force &&
        _trainingHistorySnapshotUserId == userId &&
        _trainingHistorySnapshotLimitDays >= limitDays &&
        _trainingHistorySnapshotFetchedAtUtc != null &&
        now.difference(_trainingHistorySnapshotFetchedAtUtc!) <= maxAge;
    if (hasFreshEnoughCache) return;
    if (_trainingHistorySnapshotInFlight != null) {
      await _trainingHistorySnapshotInFlight;
      return;
    }
    final task = () async {
      try {
        await fetchTrainingHistory(userId: userId, limitDays: limitDays);
      } catch (_) {
        // Best-effort prefetch only.
      }
    }();
    _trainingHistorySnapshotInFlight = task;
    try {
      await task;
    } finally {
      if (identical(_trainingHistorySnapshotInFlight, task)) {
        _trainingHistorySnapshotInFlight = null;
      }
    }
  }

  static Future<Map<String, dynamic>> fetchTrainingPlanChanges({
    required int userId,
    bool markSeen = false,
    int limit = 200,
  }) async {
    final url = Uri.parse('$baseUrl/training/plan-changes/$userId').replace(
      queryParameters: <String, String>{
        'mark_seen': markSeen.toString(),
        'limit': '$limit',
      },
    );
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    _recordServerClock(response);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      final detail = body is Map<String, dynamic>
          ? (body['detail']?.toString() ??
                'Failed to load training plan changes')
          : 'Failed to load training plan changes';
      throw Exception(detail);
    }
    final decoded = response.body.isNotEmpty ? json.decode(response.body) : {};
    final payload = decoded is Map
        ? Map<String, dynamic>.from(decoded.cast<String, dynamic>())
        : <String, dynamic>{};
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => TrainingPlanChangeEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <TrainingPlanChangeEvent>[];
    return {
      'items': items,
      'unseen_count': payload['unseen_count'] is int
          ? payload['unseen_count'] as int
          : int.tryParse('${payload['unseen_count']}') ?? 0,
      'mark_seen': payload['mark_seen'] == true,
      'ok': payload['ok'] == true,
    };
  }

  static Future<List<dynamic>> getFeedbackQuestions(String exerciseName) async {
    try {
      final safeName = Uri.encodeComponent(exerciseName);
      final url = Uri.parse(
        '$baseUrl/training/exercise/$safeName/feedback-questions',
      );
      final response = await http.get(url);
      _recordServerClock(response);

      if (response.statusCode != 200) {
        throw Exception("Failed to load feedback questions");
      }

      final questions = json.decode(response.body) as List<dynamic>;

      // Cache questions for offline access
      try {
        await FeedbackQuestionsStorage.saveQuestions(exerciseName, questions);
      } catch (_) {
        // Ignore cache errors
      }

      return questions;
    } catch (e) {
      // If network fails, try loading from cache
      try {
        final cached = await FeedbackQuestionsStorage.loadQuestions(
          exerciseName,
        );
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {
        // Ignore cache load errors
      }
      rethrow;
    }
  }

  static Future<void> submitFeedback({
    required int programExerciseId,
    required int questionIndex,
    required int answer,
  }) async {
    final url = Uri.parse('$baseUrl/training/feedback');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'program_exercise_id': programExerciseId,
        'question_index': questionIndex,
        'answer': answer,
      }),
    );
    _recordServerClock(res);
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<List<dynamic>> fetchAllExercises({
    int limit = 1000,
    int offset = 0,
    String? search,
    String? muscle,
  }) async {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if ((search ?? '').trim().isNotEmpty) {
      query['search'] = search!.trim();
    }
    if ((muscle ?? '').trim().isNotEmpty) {
      query['muscle'] = muscle!.trim();
    }
    final url = Uri.parse(
      '$baseUrl/training/exercises',
    ).replace(queryParameters: query);
    final response = await http.get(url);
    _recordServerClock(response);
    if (response.statusCode != 200) {
      throw Exception("Failed to load exercises");
    }
    return json.decode(response.body);
  }

  static Future<List<String>> fetchCompletedExerciseNames(int userId) async {
    final url = Uri.parse('$baseUrl/training/exercises/completed/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    _recordServerClock(response);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception("Failed to load completed exercise names");
    }
    final data = json.decode(response.body);
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static Future<List<String>> fetchExerciseMuscles() async {
    final url = Uri.parse('$baseUrl/training/exercises/muscles');
    final response = await http.get(url);
    _recordServerClock(response);
    if (response.statusCode != 200) {
      throw Exception("Failed to load muscles");
    }
    final data = json.decode(response.body);
    return (data as List).map((e) => e.toString()).toList();
  }

  static Future<List<dynamic>> fetchReplaceSuggestions({
    required int programExerciseId,
  }) async {
    final url = Uri.parse(
      '$baseUrl/training/exercise/$programExerciseId/replace-suggestions',
    );
    final response = await http.get(url);
    _recordServerClock(response);
    if (response.statusCode != 200) {
      throw Exception("Failed to load suggestions");
    }
    return json.decode(response.body);
  }

  static Future<void> replaceExercise({
    required int userId,
    required int programExerciseId,
    required int newExerciseId,
    required String reason,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/replace');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'user_id': userId,
        'program_exercise_id': programExerciseId,
        'new_exercise_id': newExerciseId,
        'source': 'manual',
        'reason': reason,
      }),
    );
    _recordServerClock(response);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      final detail = body is Map<String, dynamic>
          ? (body['detail']?.toString() ?? "Replace failed")
          : "Replace failed";
      throw TrainingApiException(response.statusCode, detail);
    }
  }
}
