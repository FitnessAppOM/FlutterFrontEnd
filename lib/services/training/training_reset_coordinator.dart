import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_storage.dart';
import '../core/daily_provider_push_service.dart';

/// Centralized reset clock for training-related day/week boundaries.
///
/// Priority:
/// 1) Server `Date` header (captured from training API responses)
/// 2) Local device UTC clock fallback
class TrainingResetCoordinator {
  static const _keyPrefix = 'training_reset';
  static const int localStartHour =
      DailyProviderPushService.localStartHour; // 1:00 AM local device time
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
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime _toLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

  static DateTime _effectiveDayForWeek(DateTime dt) {
    final local = _toLocal(dt);
    final hasClockTime =
        local.hour != 0 ||
        local.minute != 0 ||
        local.second != 0 ||
        local.millisecond != 0 ||
        local.microsecond != 0;
    final shifted = hasClockTime
        ? local.subtract(const Duration(hours: localStartHour))
        : local;
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  static DateTime effectiveLocalDay([DateTime? now]) {
    final local = _toLocal(now ?? currentNowUtc());
    final shifted = local.subtract(const Duration(hours: localStartHour));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  static DateTime weekStartMonday(DateTime dt) {
    final day = _effectiveDayForWeek(dt);
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
    final value = _effectiveDayForWeek(date);
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
    return !value.isBefore(start) && !value.isAfter(end);
  }

  static Future<String> currentDayToken() async {
    final now = await currentNowUtcAsync();
    return dateToken(effectiveLocalDay(now));
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
