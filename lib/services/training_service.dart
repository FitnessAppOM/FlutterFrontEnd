import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';

class TrainingService {
  static String baseUrl = ApiConfig.baseUrl;

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

    return json.decode(response.body);
  }

  static Future<void> startExercise(int programExerciseId) async {
    final url = Uri.parse('$baseUrl/training/exercise/start');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'program_exercise_id': programExerciseId}),
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
        }));
  }
  static Future<List<dynamic>> getFeedbackQuestions(String exerciseName) async {
    final safeName = Uri.encodeComponent(exerciseName);
    final url = Uri.parse('$baseUrl/training/exercise/$safeName/feedback-questions');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Failed to load feedback questions");
    }
    return json.decode(response.body);
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
  }) async {
    final url = Uri.parse('$baseUrl/training/exercise/replace');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'program_exercise_id': programExerciseId,
        'new_exercise_id': newExerciseId,
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['detail'] ?? "Replace failed");
    }
  }


}
