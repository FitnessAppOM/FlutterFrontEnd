import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import 'training_program_storage.dart';
import 'feedback_questions_storage.dart';

class TrainingService {
  static String baseUrl = ApiConfig.baseUrl;

  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  static Future<bool> generateProgram(int userId) async {
    final url = Uri.parse('$baseUrl/training/generate/$userId');
    final response = await http.post(url);

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

  /// Fetch program from cache (for offline use)
  static Future<Map<String, dynamic>?> fetchActiveProgramFromCache() async {
    return await TrainingProgramStorage.loadProgram();
  }

  /// Start an exercise and (optionally) record entry_date (user local date) on backend.
  /// When entryDate is provided, backend can map date -> training_day_id for diet inference.
  static Future<void> startExercise(int programExerciseId, {DateTime? entryDate}) async {
    final url = Uri.parse('$baseUrl/training/exercise/start');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'program_exercise_id': programExerciseId,
        if (entryDate != null) 'entry_date': _dateParam(entryDate),
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Failed to start exercise");
    }
  }


  static Future<void> saveWeight(
      int programExerciseId, double weight) async {
    final url = Uri.parse('$baseUrl/training/exercise/weight');
    await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'program_exercise_id': programExerciseId,
          'weight_used': weight,
        }));
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
    await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'program_exercise_id': programExerciseId,
          'performed_sets': sets,
          'performed_reps': reps,
          'performed_rir': rir,
          'performed_time_seconds': durationSeconds,
          if (entryDate != null) 'entry_date': _dateParam(entryDate),
        }));
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
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'program_exercise_id': programExerciseId,
        'question_index': questionIndex,
        'answer': answer,
      }),
    );
  }
  static Future<List<dynamic>> fetchAllExercises() async {
    final url = Uri.parse('$baseUrl/training/exercises');
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception("Failed to load exercises");
    }
    return json.decode(response.body);
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
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'program_exercise_id': programExerciseId,
        'new_exercise_id': newExerciseId,
        'source': 'manual',
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? "Replace failed");
    }
  }


}
