import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores feedback questions locally for offline access
class FeedbackQuestionsStorage {
  static const _keyPrefix = "feedback_questions_";

  /// Save questions for an exercise
  static Future<void> saveQuestions(String exerciseName, List<dynamic> questions) async {
    final sp = await SharedPreferences.getInstance();
    final key = _keyForExercise(exerciseName);
    
    // Save questions as JSON
    await sp.setString(key, jsonEncode(questions));
  }

  /// Load cached questions for an exercise
  static Future<List<dynamic>> loadQuestions(String exerciseName) async {
    final sp = await SharedPreferences.getInstance();
    final key = _keyForExercise(exerciseName);
    final raw = sp.getString(key);

    if (raw == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded;
    } catch (_) {
      return [];
    }
  }

  /// Check if questions exist in cache
  static Future<bool> hasQuestions(String exerciseName) async {
    final sp = await SharedPreferences.getInstance();
    final key = _keyForExercise(exerciseName);
    return sp.containsKey(key);
  }

  /// Clear cached questions for an exercise
  static Future<void> clearQuestions(String exerciseName) async {
    final sp = await SharedPreferences.getInstance();
    final key = _keyForExercise(exerciseName);
    await sp.remove(key);
  }

  static String _keyForExercise(String exerciseName) {
    // Normalize exercise name for key (remove special chars, lowercase)
    final normalized = exerciseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return "$_keyPrefix$normalized";
  }
}
