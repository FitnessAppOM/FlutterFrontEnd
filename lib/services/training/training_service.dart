import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'training_program_storage.dart';
import '../core/feedback_questions_storage.dart';

class TrainingService {
  static String baseUrl = ApiConfig.baseUrl;

  /// Prefer full [animationUrl] (e.g. GCS). If missing, return empty string
  /// and let the UI show a placeholder instead of falling back to local /static.
  static String animationImageUrl(String? animationUrl, String? animationRelPath) {
    final direct = (animationUrl ?? '').trim();
    if (direct.isNotEmpty &&
        (direct.startsWith('http://') || direct.startsWith('https://'))) {
      return direct;
    }
    return '';
  }

  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
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
      final body = response.body.isNotEmpty
          ? json.decode(response.body)
          : {};
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
    
    return program;
  }

  static Future<Map<String, dynamic>> fetchTrainingProgress({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final startParam = _dateParam(start);
    final endParam = _dateParam(end);
    final url = Uri.parse(
      '$baseUrl/training/progress/$userId?start=$startParam&end=$endParam',
    );
    final headers = await AccountStorage.getAuthHeaders();
    final response = await http.get(url, headers: headers);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception("Failed to load training progress");
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Fetch program from cache (for offline use)
  static Future<Map<String, dynamic>?> fetchActiveProgramFromCache() async {
    return await TrainingProgramStorage.loadProgram();
  }

  /// Start an exercise and (optionally) record entry_date (user local date) on backend.
  /// When entryDate is provided, backend can map date -> training_day_id for diet inference.
  static Future<void> startExercise(int programExerciseId, {DateTime? entryDate}) async {
    final url = Uri.parse('$baseUrl/training/exercise/start');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
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


  static Future<void> saveWeight(
      int programExerciseId, double weight) async {
    final url = Uri.parse('$baseUrl/training/exercise/weight');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final res = await http.post(url,
        headers: headers,
        body: json.encode({
          'program_exercise_id': programExerciseId,
          'weight_used': weight,
        }));
    await AccountStorage.handle401(res.statusCode);
  }

  static Future<void> finishExercise({
    required int programExerciseId,
    required int sets,
    required int reps,
    required int rir,
    required int durationSeconds,
    DateTime? entryDate,
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/finish');
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final res = await http.post(url,
        headers: headers,
        body: json.encode({
          'program_exercise_id': programExerciseId,
          'performed_sets': sets,
          'performed_reps': reps,
          'performed_rir': rir,
          'performed_time_seconds': durationSeconds,
          if (entryDate != null) 'entry_date': _dateParam(entryDate),
        }));
    await AccountStorage.handle401(res.statusCode);
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
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
    final body = <String, dynamic>{
      'distance_km': distanceKm,
      'avg_pace_min_km': avgPaceMinKm,
      'duration_seconds': durationSeconds,
    };
    if (steps != null) body['steps'] = steps;
    if (programExerciseId != null) body['program_exercise_id'] = programExerciseId;
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
    final url = Uri.parse('$baseUrl/training/cardio/history/$userId?limit=$limit');
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
    final url = Uri.parse('$baseUrl/training/cardio/history/$userId/detail/$sessionId');
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
  static Future<List<dynamic>> getFeedbackQuestions(String exerciseName) async {
    try {
      final safeName = Uri.encodeComponent(exerciseName);
      final url = Uri.parse('$baseUrl/training/exercise/$safeName/feedback-questions');
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
        final cached = await FeedbackQuestionsStorage.loadQuestions(exerciseName);
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
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
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
    final url = Uri.parse('$baseUrl/training/exercise/$programExerciseId/replace-suggestions');
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
    final headers = {'Content-Type': 'application/json', ...await AccountStorage.getAuthHeaders()};
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
      throw Exception(body['detail'] ?? "Replace failed");
    }
  }


}
