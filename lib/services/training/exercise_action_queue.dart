import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';
import 'training_service.dart';

/// Queues exercise actions for offline sync
class ExerciseActionQueue {
  static const _key = "exercise_action_queue";
  static bool _syncing = false;

  /// Action types
  static const String actionStart = "start";
  static const String actionFinish = "finish";
  static const String actionWeight = "weight";
  static const String actionFeedback = "feedback";
  static const String actionReplace = "replace";

  /// Add action to queue
  static Future<void> queueAction({
    required String action,
    required int programExerciseId,
    Map<String, dynamic>? data,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final queueKey = "${_key}_u$userId";
    
    // Load existing queue
    final existing = await _loadQueue(userId);
    
    // Add new action
    existing.add({
      "action": action,
      "program_exercise_id": programExerciseId,
      "timestamp": DateTime.now().toIso8601String(),
      "data": data ?? {},
    });
    
    // Save queue
    await sp.setString(queueKey, jsonEncode(existing));
  }

  /// Load all queued actions
  static Future<List<Map<String, dynamic>>> loadQueue() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return [];
    return await _loadQueue(userId);
  }

  static Future<List<Map<String, dynamic>>> _loadQueue(int userId) async {
    final sp = await SharedPreferences.getInstance();
    final queueKey = "${_key}_u$userId";
    final raw = sp.getString(queueKey);
    
    if (raw == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// Process and sync all queued actions
  static Future<void> syncQueue() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final queue = await loadQueue();
      if (queue.isEmpty) return;

      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      final sp = await SharedPreferences.getInstance();
      final queueKey = "${_key}_u$userId";

      final List<Map<String, dynamic>> failed = [];

      for (final action in queue) {
        try {
          await _processAction(action);
        } catch (e) {
          final actionType = action["action"] as String?;
          // Drop non-retryable replace errors (e.g., started/completed)
          if (actionType == actionReplace &&
              e is TrainingApiException &&
              !e.isRetryable) {
            // ignore: avoid_print
            print("Dropping replace action (non-retryable): $e");
            continue;
          }

          // If sync fails, keep action in queue
          failed.add(action);
          // ignore: avoid_print
          print("Failed to sync exercise action: $e");
        }
      }

      // Save remaining failed actions (or clear if all succeeded)
      if (failed.isEmpty) {
        await sp.remove(queueKey);
      } else {
        await sp.setString(queueKey, jsonEncode(failed));
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _processAction(Map<String, dynamic> action) async {
    final actionType = action["action"] as String;
    final programExerciseId = action["program_exercise_id"] as int;
    final data = action["data"] as Map<String, dynamic>? ?? {};
    final entryDate = data["entry_date"] as String?;

    switch (actionType) {
      case actionStart:
        await TrainingService.startExercise(
          programExerciseId,
          entryDate: entryDate != null ? DateTime.tryParse(entryDate) : null,
        );
        break;
      case actionFinish:
        await TrainingService.finishExercise(
          programExerciseId: programExerciseId,
          sets: data["sets"] as int? ?? 0,
          reps: data["reps"] as int? ?? 0,
          rir: data["rir"] as int? ?? 0,
          durationSeconds: data["duration_seconds"] as int? ?? 0,
          entryDate: entryDate != null ? DateTime.tryParse(entryDate) : null,
        );
        break;
      case actionWeight:
        await TrainingService.saveWeight(
          programExerciseId,
          data["weight"] as double? ?? 0.0,
        );
        break;
      case actionFeedback:
        await TrainingService.submitFeedback(
          programExerciseId: programExerciseId,
          questionIndex: data["question_index"] as int? ?? 0,
          answer: data["answer"] as int? ?? 0,
        );
        break;
      case actionReplace:
        final userId = data["user_id"] as int? ?? 0;
        final newExerciseId = data["new_exercise_id"] as int? ?? 0;
        final newExerciseName = data["new_exercise_name"] as String? ?? "";
        final reason = data["reason"] as String? ?? "No reason provided";
        
        await TrainingService.replaceExercise(
          userId: userId,
          programExerciseId: programExerciseId,
          newExerciseId: newExerciseId,
          reason: reason,
        );
        
        // Preload feedback questions for the new exercise after replacement
        if (newExerciseName.isNotEmpty) {
          try {
            await TrainingService.getFeedbackQuestions(newExerciseName);
          } catch (_) {
            // Ignore if questions can't be loaded
          }
        }
        break;
    }
  }

  /// Clear queue
  static Future<void> clearQueue() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final queueKey = "${_key}_u$userId";
    await sp.remove(queueKey);
  }
}
