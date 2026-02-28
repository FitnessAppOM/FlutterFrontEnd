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
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static String _userKey(int userId, String key) => '${_keyPrefix}_${key}_u$userId';

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

    if (programId != null && storedProgramId != null && storedProgramId != programId) {
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

  static Future<TrainingProgressSnapshot?> getProgressForWeek(DateTime anchor) async {
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

  static Future<void> clearAll() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    await _clearProgress(sp, userId);
    await sp.remove(_userKey(userId, 'program_id'));
    await sp.remove(_userKey(userId, 'days_per_week'));
  }
}
