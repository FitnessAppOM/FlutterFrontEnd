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
  static const String actionSetAdd = "set_add";
  static const String actionSetUpsert = "set_upsert";
  static const String actionSetDelete = "set_delete";
  static const String actionSessionFinish = "session_finish";

  static String _dateToken(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  static String? _normalizeEntryDateToken(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return raw;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return _dateToken(parsed);
  }

  static String? _sessionFinishDateTokenFromAction(
    Map<String, dynamic> action,
  ) {
    if (action["action"] != actionSessionFinish) return null;
    final data = action["data"];
    if (data is! Map) return null;
    return _normalizeEntryDateToken(data["entry_date"]);
  }

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

    final payloadData = Map<String, dynamic>.from(data ?? const {});
    if (action == actionStart ||
        action == actionFinish ||
        action == actionSessionFinish) {
      final normalized = _normalizeEntryDateToken(payloadData["entry_date"]);
      payloadData["entry_date"] = normalized ?? _dateToken(DateTime.now());
    }

    if (action == actionSessionFinish) {
      final token = _normalizeEntryDateToken(payloadData["entry_date"]);
      if (token != null) {
        final alreadyQueued = existing.any(
          (item) => _sessionFinishDateTokenFromAction(item) == token,
        );
        if (alreadyQueued) return;
      }
    }

    // Add new action
    existing.add({
      "action": action,
      "program_exercise_id": programExerciseId,
      "timestamp": DateTime.now().toIso8601String(),
      "data": payloadData,
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
      bool previousActionFailed = false;

      for (final action in queue) {
        final actionType = action["action"] as String?;
        if (actionType == actionSessionFinish && previousActionFailed) {
          failed.add(action);
          continue;
        }
        if (actionType == actionSessionFinish) {
          final hasActiveSession = await TrainingService.hasActiveSession();
          if (!hasActiveSession) {
            // Session was already closed on backend; skip stale replay.
            continue;
          }
        }
        try {
          await _processAction(action);
        } catch (e) {
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
          previousActionFailed = true;
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
    DateTime? parsedEntryDate = entryDate != null
        ? DateTime.tryParse(entryDate)
        : null;
    parsedEntryDate ??= DateTime.tryParse(
      action["timestamp"]?.toString() ?? '',
    );
    final effectiveEntryDate = parsedEntryDate ?? DateTime.now();

    switch (actionType) {
      case actionStart:
        await TrainingService.startExercise(
          programExerciseId,
          entryDate: effectiveEntryDate,
        );
        break;
      case actionFinish:
        await TrainingService.finishExercise(
          programExerciseId: programExerciseId,
          sets: data.containsKey("sets") ? data["sets"] as int? : null,
          reps: data.containsKey("reps") ? data["reps"] as int? : null,
          rir: data.containsKey("rir") ? data["rir"] as int? : null,
          durationSeconds: data["duration_seconds"] as int? ?? 0,
          entryDate: effectiveEntryDate,
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
      case actionSetAdd:
        await TrainingService.addExerciseSet(
          programExerciseId: programExerciseId,
          cloneLast: data["clone_last"] as bool? ?? true,
        );
        break;
      case actionSetUpsert:
        await TrainingService.upsertExerciseSet(
          programExerciseId: programExerciseId,
          setIndex: data["set_index"] as int? ?? 1,
          reps: data.containsKey("reps") ? data["reps"] as int? : null,
          rir: data.containsKey("rir") ? data["rir"] as int? : null,
          weightKg: (data.containsKey("weight_kg") && data["weight_kg"] != null)
              ? (data["weight_kg"] as num).toDouble()
              : null,
          completed: data.containsKey("completed")
              ? data["completed"] as bool?
              : null,
          performedTimeSeconds: data.containsKey("performed_time_seconds")
              ? data["performed_time_seconds"] as int?
              : null,
          restAfterSeconds: data.containsKey("rest_after_seconds")
              ? data["rest_after_seconds"] as int?
              : null,
        );
        break;
      case actionSetDelete:
        await TrainingService.deleteExerciseSet(
          programExerciseId: programExerciseId,
          setIndex: data["set_index"] as int? ?? 1,
        );
        break;
      case actionSessionFinish:
        await TrainingService.finishSession(entryDate: effectiveEntryDate);
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
