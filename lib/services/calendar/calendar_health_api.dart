import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/network_status_service.dart';
import 'calendar_food_commands.dart';
import 'day_timeline_service.dart';
import 'calendar_time_zone.dart';

/// Manual health logs have their own receipt; never enqueue them as Diet edits.
class CalendarHealthApi {
  static final changes = ValueNotifier<int>(0);
  static final _busy = <int>{};
  static String _key(int user) => 'calendar_pending_health_u$user';
  static Future<void> _account(int user) async {
    if (await AccountStorage.getUserId() != user) {
      throw const CalendarCommandError('calendar_time_account_changed');
    }
  }

  static Future<Map<String, dynamic>?> pending(int user) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(user));
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> day(int user, DateTime date) =>
      _read(user, 'sessions?entry_date=${calendarDate(date)}');

  static Future<Map<String, dynamic>?> range(
    int user,
    DateTime start,
    DateTime end,
  ) => _read(
    user,
    'session-days?start=${calendarDate(start)}&end=${calendarDate(end)}',
  );

  static Future<Map<String, dynamic>?> _read(int user, String path) async {
    await _account(user);
    final headers = await AccountStorage.getAuthHeaders();
    await _account(user);
    final r = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/calendar/$user/$path'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    await _account(user);
    await AccountStorage.handle401(r.statusCode);
    if ({404, 405, 503}.contains(r.statusCode)) return null;
    if (r.statusCode != 200) {
      throw const CalendarCommandError('calendar_health_load_error');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (path.startsWith('sessions?')) {
      if (data['entry_date'] != Uri.parse(path).queryParameters['entry_date'] ||
          data['sessions'] is! List ||
          data['sleep_summary'] is! Map ||
          data['sleep_summary']['minutes'] is! num ||
          data['capabilities'] is! List) {
        throw const FormatException('Invalid session response');
      }
      for (final row in data['sessions'] as List) {
        if (row is! Map ||
            !{'activity', 'sleep'}.contains(row['kind']) ||
            row['source'] is! Map ||
            row['source']['id'] is! int ||
            row['source']['revision'] is! int ||
            row['duration_seconds'] is! num ||
            row['capabilities'] is! List) {
          throw const FormatException('Invalid session');
        }
        CalendarTimeZone.inZone(
          DateTime.parse(row['started_at'] as String),
          row['timezone'] as String,
        );
        CalendarTimeZone.inZone(
          DateTime.parse(row['ended_at'] as String),
          row['timezone'] as String,
        );
      }
    } else if (data['days'] is! List) {
      throw const FormatException('Invalid session day response');
    }
    return data;
  }

  static Future<void> submit(
    int user,
    Map<String, dynamic> request, {
    Map<String, dynamic>? preview,
  }) => _run(user, {
    ...request,
    'operation_key': DayTimelineService.newEntryKey(user),
    if (preview != null) '_preview': preview,
  });
  static Future<void> retry(int user) => _run(user, null);

  static Future<void> _run(int user, Map<String, dynamic>? fresh) async {
    if (!_busy.add(user)) {
      throw const CalendarCommandError('calendar_health_pending');
    }
    try {
      await _account(user);
      if (NetworkStatusService.instance.isOffline) {
        throw const CalendarCommandError('calendar_time_online');
      }
      final stored = await pending(user);
      if (fresh != null && stored != null) {
        throw const CalendarCommandError('calendar_health_pending');
      }
      final request = fresh ?? stored;
      if (request == null) {
        throw const CalendarCommandError('calendar_time_reload', reload: true);
      }
      final encoded = jsonEncode(
        Map<String, dynamic>.from(request)..remove('_preview'),
      );
      final headers = await AccountStorage.getAuthHeaders();
      await _account(user);
      final prefs = await SharedPreferences.getInstance();
      if (fresh != null &&
          !await prefs.setString(_key(user), jsonEncode(request))) {
        throw const CalendarCommandError('calendar_time_storage_error');
      }
      changes.value++;
      // The account can change during the storage await; never send with another account's headers.
      await _account(user);
      final r = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/calendar/$user/sessions/command'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: encoded,
          )
          .timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) {
        var missing = false;
        try {
          missing =
              r.statusCode == 404 &&
              (jsonDecode(r.body) as Map)['detail'] ==
                  'Manual session not found';
        } catch (_) {
          /* An unavailable proxy/route is not proof of rejection. */
        }
        if ({400, 403, 409, 422}.contains(r.statusCode) || missing) {
          await prefs.remove(_key(user));
          changes.value++;
          throw CalendarCommandError(
            r.statusCode == 409
                ? 'calendar_health_conflict'
                : 'calendar_health_rejected',
            reload: true,
          );
        }
        if (await AccountStorage.getUserId() == user) {
          await AccountStorage.handle401(r.statusCode);
        }
        throw const CalendarCommandError('calendar_time_uncertain');
      }
      final result = jsonDecode(r.body) as Map;
      if (result['status'] != 'committed' ||
          result['operation_key'] != request['operation_key']) {
        throw const CalendarCommandError('calendar_time_uncertain');
      }
      // Cleanup failure must not disguise a committed write; replay remains safe.
      try {
        await prefs.remove(_key(user));
      } catch (_) {
        /* Keep exact receipt. */
      }
      if (await AccountStorage.getUserId() == user) changes.value++;
    } finally {
      _busy.remove(user);
    }
  }
}
