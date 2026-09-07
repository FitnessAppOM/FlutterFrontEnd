import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../core/network_status_service.dart';
import '../core/offline_queue_signal.dart';
import 'daily_journal_storage.dart';

class DailyJournalActionQueue {
  DailyJournalActionQueue._();

  static const _prefix = 'daily_journal_action_queue';
  static bool _syncing = false;

  static String _key(int userId) => '${_prefix}_u$userId';

  static Future<List<Map<String, dynamic>>> _load(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(userId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> enqueue(Map<String, dynamic> body) async {
    final userId = body['user_id'] as int? ?? await AccountStorage.getUserId();
    final date = body['entry_date']?.toString();
    if (userId == null || date == null || date.isEmpty) return;
    final queue = await _load(userId);
    queue.removeWhere((item) => item['body']?['entry_date'] == date);
    queue.add({
      'body': Map<String, dynamic>.from(body),
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    // A journal has at most one entry per day. Keep a generous bounded window
    // so corrupted or abandoned queues cannot grow forever.
    if (queue.length > 31) queue.removeRange(0, queue.length - 31);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(userId), jsonEncode(queue));
    OfflineQueueSignal.notifyChanged();
  }

  static Future<int> pendingCount() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return 0;
    return (await _load(userId)).length;
  }

  static Future<void> syncQueue() async {
    if (_syncing) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    _syncing = true;
    try {
      final queue = await _load(userId);
      if (queue.isEmpty) return;
      final failed = <Map<String, dynamic>>[];
      for (final action in queue) {
        final rawBody = action['body'];
        if (rawBody is! Map) continue;
        final body = Map<String, dynamic>.from(rawBody);
        if (body['user_id'] != userId) continue;
        try {
          final response = await http
              .post(
                Uri.parse('${ApiConfig.baseUrl}/daily-journal/'),
                headers: {
                  'Content-Type': 'application/json',
                  ...await AccountStorage.getAuthHeaders(),
                },
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 10));
          await AccountStorage.handle401(response.statusCode);
          NetworkStatusService.instance.reportServerReached();
          if (response.statusCode == 200) {
            await DailyJournalStorage.save(userId, body);
          } else {
            failed.add(action);
          }
        } catch (error) {
          NetworkStatusService.instance.reportNetworkFailure(error);
          failed.add(action);
        }
      }
      final preferences = await SharedPreferences.getInstance();
      if (failed.isEmpty) {
        await preferences.remove(_key(userId));
      } else {
        await preferences.setString(_key(userId), jsonEncode(failed));
      }
      OfflineQueueSignal.notifyChanged();
    } finally {
      _syncing = false;
    }
  }
}
