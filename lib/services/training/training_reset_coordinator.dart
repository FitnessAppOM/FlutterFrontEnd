import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';

/// Centralized reset clock for training-related day/week boundaries.
///
/// Priority:
/// 1) Server `Date` header (captured from training API responses)
/// 2) Local device UTC clock fallback
class TrainingResetCoordinator {
  static const _keyPrefix = 'training_reset';
  static int? _serverOffsetMs;
  static int? _loadedForUserId;

  static String _offsetKey(int userId) =>
      '${_keyPrefix}_server_offset_ms_u$userId';

  static Future<void> ensureInitialized() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    if (_loadedForUserId == userId) return;
    final sp = await SharedPreferences.getInstance();
    _serverOffsetMs = sp.getInt(_offsetKey(userId));
    _loadedForUserId = userId;
  }

  static DateTime currentNowUtc() {
    final nowUtc = DateTime.now().toUtc();
    final offset = _serverOffsetMs;
    if (offset == null || offset == 0) return nowUtc;
    return nowUtc.add(Duration(milliseconds: offset));
  }

  static Future<DateTime> currentNowUtcAsync() async {
    await ensureInitialized();
    return currentNowUtc();
  }

  static String dateToken(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime weekStartMonday(DateTime dt) {
    final utc = dt.toUtc();
    final day = DateTime.utc(utc.year, utc.month, utc.day);
    final daysSinceMonday = (day.weekday + 6) % 7; // Monday=0 ... Sunday=6
    return day.subtract(Duration(days: daysSinceMonday));
  }

  static DateTime weekEndSunday(DateTime dt) {
    final start = weekStartMonday(dt);
    return start.add(const Duration(days: 6));
  }

  static bool isInWeek(
    DateTime date, {
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final valueUtc = date.toUtc();
    final startUtc = weekStart.toUtc();
    final endUtc = weekEnd.toUtc();
    return !valueUtc.isBefore(startUtc) && !valueUtc.isAfter(endUtc);
  }

  static Future<String> currentDayToken() async {
    final now = await currentNowUtcAsync();
    return dateToken(now);
  }

  static Future<String> currentWeekStartToken() async {
    final now = await currentNowUtcAsync();
    return dateToken(weekStartMonday(now));
  }

  static Future<void> captureServerTimeFromHeaders(
    Map<String, String> headers,
  ) async {
    String? rawDate;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'date') {
        rawDate = entry.value;
        break;
      }
    }
    if (rawDate == null || rawDate.trim().isEmpty) return;

    DateTime parsed;
    try {
      parsed = HttpDate.parse(rawDate).toUtc();
    } catch (_) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final offset =
        parsed.millisecondsSinceEpoch - nowUtc.millisecondsSinceEpoch;
    _serverOffsetMs = offset;

    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    _loadedForUserId = userId;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_offsetKey(userId), offset);
  }
}
