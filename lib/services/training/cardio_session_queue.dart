import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';
import 'training_service.dart';

/// Queues cardio sessions for offline sync
class CardioSessionQueue {
  static const _key = "cardio_session_queue";

  static Future<void> queueSession(Map<String, dynamic> payload) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;

    final sp = await SharedPreferences.getInstance();
    final queueKey = "${_key}_u$userId";
    final existing = await _loadQueue(userId);
    existing.add(payload);
    await sp.setString(queueKey, jsonEncode(existing));
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

  static Future<void> syncQueue() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final queueKey = "${_key}_u$userId";
    final queue = await _loadQueue(userId);
    if (queue.isEmpty) return;

    final List<Map<String, dynamic>> failed = [];
    for (final item in queue) {
      try {
        await TrainingService.saveCardioSession(
          programExerciseId: item["program_exercise_id"] as int?,
          exerciseId: item["exercise_id"] as int?,
          distanceKm: (item["distance_km"] as num?)?.toDouble() ?? 0,
          avgPaceMinKm: (item["avg_pace_min_km"] as num?)?.toDouble() ??
              (item["avg_speed_kmh"] as num?)?.toDouble() ??
              0,
          durationSeconds: item["duration_seconds"] as int? ?? 0,
          steps: item["steps"] as int?,
          routePoints: (item["route_points"] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          entryDate: item["entry_date"] != null
              ? DateTime.tryParse(item["entry_date"] as String)
              : null,
        );
      } catch (_) {
        failed.add(item);
      }
    }

    if (failed.isEmpty) {
      await sp.remove(queueKey);
    } else {
      await sp.setString(queueKey, jsonEncode(failed));
    }
  }
}
