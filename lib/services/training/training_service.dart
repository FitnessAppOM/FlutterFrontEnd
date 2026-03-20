import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'training_program_storage.dart';
import 'training_progress_storage.dart';
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

class TrainingService {
  static String baseUrl = ApiConfig.baseUrl;
  static final Map<String, ImageProvider> _gifProviders = {};
  static final Set<String> _gifEverLoaded = <String>{};
  static final Map<String, ImageInfo> _gifFrames = {};

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

  static Future<bool> generateProgram(int userId) async {
    final url = Uri.parse('$baseUrl/training/generate/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.post(url, headers: headers);

    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode == 200) {
      return true;
    }

    if (response.statusCode == 400) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? 'Training generation failed');
    }

    throw Exception('Unexpected error (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> fetchActiveProgram(int userId) async {
    final url = Uri.parse('$baseUrl/training/current/$userId');
    final response = await http.get(url);

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
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<List<Map<String, dynamic>>> fetchExerciseSets(
    int programExerciseId,
  ) async {
    final url = Uri.parse('$baseUrl/training/exercise/$programExerciseId/sets');
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
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
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load current session");
    }
    final data = json.decode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
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
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to finish session");
    }
  }

  static Future<void> saveCardioSession({
    int? programExerciseId,
    int? exerciseId,
    required double distanceKm,
    required double avgPaceMinKm,
    required int durationSeconds,
    int? steps,
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
    if (programExerciseId != null)
      body['program_exercise_id'] = programExerciseId;
    if (exerciseId != null) body['exercise_id'] = exerciseId;
    if (routePoints != null) body['route_points'] = routePoints;
    if (entryDate != null) body['entry_date'] = _dateParam(entryDate);
    final res = await http.post(url, headers: headers, body: json.encode(body));
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
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode != 200) {
      throw Exception("Failed to load training history");
    }
    final data = json.decode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  static Future<List<dynamic>> getFeedbackQuestions(String exerciseName) async {
    try {
      final safeName = Uri.encodeComponent(exerciseName);
      final url = Uri.parse(
        '$baseUrl/training/exercise/$safeName/feedback-questions',
      );
      final response = await http.get(url);

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
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<List<dynamic>> fetchAllExercises() async {
    final url = Uri.parse('$baseUrl/training/exercises');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("Failed to load exercises");
    }
    return json.decode(response.body);
  }

  static Future<List<String>> fetchCompletedExerciseNames(int userId) async {
    final url = Uri.parse('$baseUrl/training/exercises/completed/$userId');
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
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
