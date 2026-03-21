import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';

class TrainingProgressSnapshot {
  const TrainingProgressSnapshot({
    required this.completed,
    required this.total,
    required this.weekStart,
    required this.programId,
  });

  final int completed;
  final int total;
  final String weekStart;
  final int? programId;
}

class TrainingProgressStorage {
  static const _keyPrefix = 'training_progress';

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime _weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    // Monday 00:00 as week start (aligns with exercise cards).
    final daysSinceMonday = (day.weekday + 6) % 7; // Monday=0 ... Sunday=6
    return day.subtract(Duration(days: daysSinceMonday));
  }

  static String _userKey(int userId, String key) =>
      '${_keyPrefix}_${key}_u$userId';

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static Future<void> syncProgram(Map<String, dynamic> program) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();

    final programId = _toInt(program['program_id']);
    final daysPerWeek = _toInt(program['training_days_per_week']);

    final programIdKey = _userKey(userId, 'program_id');
    final storedProgramId = sp.getInt(programIdKey);

    if (programId != null &&
        storedProgramId != null &&
        storedProgramId != programId) {
      await _clearProgress(sp, userId);
    }

    if (programId != null) {
      await sp.setInt(programIdKey, programId);
    }

    if (daysPerWeek != null) {
      await sp.setInt(_userKey(userId, 'days_per_week'), daysPerWeek);
    }
  }

  static Future<void> recordTrainingDayCompleted(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();

    final weekStartKey = _userKey(userId, 'week_start');
    final currentWeekStart = _dateKey(_weekStart(date));
    final storedWeekStart = sp.getString(weekStartKey);
    if (storedWeekStart != null && storedWeekStart != currentWeekStart) {
      await _clearProgress(sp, userId);
    }

    await sp.setString(weekStartKey, currentWeekStart);

    final completedKey = _userKey(userId, 'completed_days');
    final raw = sp.getString(completedKey);
    final Set<String> days = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString();
            if (s != null && s.isNotEmpty) days.add(s);
          }
        }
      } catch (_) {
        // ignore parse errors
      }
    }

    days.add(_dateKey(date));
    await sp.setString(completedKey, jsonEncode(days.toList()));
  }

  static Future<TrainingProgressSnapshot?> getProgressForWeek(
    DateTime anchor,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();

    final weekStartKey = _userKey(userId, 'week_start');
    final currentWeekStart = _dateKey(_weekStart(anchor));
    final storedWeekStart = sp.getString(weekStartKey);
    if (storedWeekStart != null && storedWeekStart != currentWeekStart) {
      await _clearProgress(sp, userId);
    }
    await sp.setString(weekStartKey, currentWeekStart);

    final completedKey = _userKey(userId, 'completed_days');
    final raw = sp.getString(completedKey);
    final Set<String> days = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString();
            if (s != null && s.isNotEmpty) days.add(s);
          }
        }
      } catch (_) {
        // ignore parse errors
      }
    }

    final total = sp.getInt(_userKey(userId, 'days_per_week')) ?? 0;
    final programId = sp.getInt(_userKey(userId, 'program_id'));
    return TrainingProgressSnapshot(
      completed: days.length,
      total: total,
      weekStart: currentWeekStart,
      programId: programId,
    );
  }

  static Future<void> _clearProgress(SharedPreferences sp, int userId) async {
    await sp.remove(_userKey(userId, 'completed_days'));
    await sp.remove(_userKey(userId, 'week_start'));
  }

  static Future<void> saveExerciseTimerState(
    int programExerciseId,
    Map<String, dynamic> state,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final key = _userKey(userId, 'ex_timer_$programExerciseId');
    await sp.setString(key, jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> loadExerciseTimerState(
    int programExerciseId,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final key = _userKey(userId, 'ex_timer_$programExerciseId');
    final raw = sp.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> clearExerciseTimerState(int programExerciseId) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final key = _userKey(userId, 'ex_timer_$programExerciseId');
    await sp.remove(key);
  }

  static Future<void> clearOtherExerciseTimers(
    int keepProgramExerciseId,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final prefix = '${_keyPrefix}_ex_timer_';
    final suffix = '_u$userId';
    final keepKey = '${prefix}${keepProgramExerciseId}$suffix';
    for (final key in sp.getKeys()) {
      if (key == keepKey) continue;
      if (key.startsWith(prefix) && key.endsWith(suffix)) {
        await sp.remove(key);
      }
    }
  }

  static Future<void> clearAllExerciseTimers() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final prefix = '${_keyPrefix}_ex_timer_';
    final suffix = '_u$userId';
    for (final key in sp.getKeys()) {
      if (key.startsWith(prefix) && key.endsWith(suffix)) {
        await sp.remove(key);
      }
    }
  }

  static Future<void> markExerciseInstructionsSeen(
    int programExerciseId,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'ex_instr_seen_${programExerciseId}_$today');
    await sp.setBool(key, true);
  }

  static Future<bool> hasExerciseInstructionsSeen(int programExerciseId) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return false;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'ex_instr_seen_${programExerciseId}_$today');
    return sp.getBool(key) ?? false;
  }

  static Future<void> saveLastExerciseFinishedMs(int ms) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'last_ex_finished_ms_$today');
    await sp.setInt(key, ms);
  }

  static Future<void> saveSessionCompletedExerciseName(
    String exerciseName, {
    int? finishedAtMs,
  }) async {
    final trimmed = exerciseName.trim();
    if (trimmed.isEmpty) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'session_done_ex_names_$today');
    final List<Map<String, dynamic>> items = [];
    final raw = sp.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final it in decoded) {
            if (it is Map) {
              final name = it['name']?.toString().trim() ?? '';
              final ms = _toInt(it['ms']);
              if (name.isEmpty || ms == null) continue;
              items.add({'name': name, 'ms': ms});
            }
          }
        }
      } catch (_) {
        // ignore parse errors
      }
    }
    final when = finishedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    items.add({'name': trimmed, 'ms': when});
    if (items.length > 100) {
      items.removeRange(0, items.length - 100);
    }
    await sp.setString(key, jsonEncode(items));
  }

  static Future<List<String>> getSessionCompletedExerciseNamesSince(
    int sinceMs,
  ) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return const [];
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'session_done_ex_names_$today');
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return const [];

    final seen = <String>{};
    final result = <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final it in decoded) {
          if (it is! Map) continue;
          final name = it['name']?.toString().trim() ?? '';
          final ms = _toInt(it['ms']) ?? 0;
          if (name.isEmpty || ms < sinceMs) continue;
          final key = name.toLowerCase();
          if (!seen.add(key)) continue;
          result.add(name);
        }
      }
    } catch (_) {
      return const [];
    }
    return result;
  }

  static Future<int?> getLastExerciseFinishedMs() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'last_ex_finished_ms_$today');
    return sp.getInt(key);
  }

  static Future<void> recordWorkoutStart() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'workout_start_ms_$today');
    if (sp.containsKey(key)) return;
    await sp.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<int?> getWorkoutStartMs() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'workout_start_ms_$today');
    return sp.getInt(key);
  }

  static Future<void> clearWorkoutStart() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final key = _userKey(userId, 'workout_start_ms_$today');
    await sp.remove(key);
  }

  static Future<void> saveExerciseRestPreset(int seconds) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_userKey(userId, 'ex_rest_preset'), seconds);
  }

  static Future<int> getExerciseRestPreset() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return 60;
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_userKey(userId, 'ex_rest_preset')) ?? 60;
  }

  static Future<void> saveExerciseRestCountdown({
    required int totalSeconds,
    required int startedAtMs,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final prefix = _userKey(userId, 'ex_rest_cd_$today');
    await sp.setInt('${prefix}_total', totalSeconds);
    await sp.setInt('${prefix}_started', startedAtMs);
  }

  static Future<Map<String, dynamic>?> loadExerciseRestCountdown() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final prefix = _userKey(userId, 'ex_rest_cd_$today');
    final total = sp.getInt('${prefix}_total');
    final started = sp.getInt('${prefix}_started');
    if (total == null || started == null || total <= 0) return null;
    return {'totalSeconds': total, 'startedAtMs': started};
  }

  static Future<void> clearExerciseRestCountdown() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final prefix = _userKey(userId, 'ex_rest_cd_$today');
    await sp.remove('${prefix}_total');
    await sp.remove('${prefix}_started');
  }

  static Future<void> clearAll() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    await _clearProgress(sp, userId);
    await sp.remove(_userKey(userId, 'program_id'));
    await sp.remove(_userKey(userId, 'days_per_week'));
  }
}
