import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DailyJournalStorage {
  DailyJournalStorage._();

  static const _prefix = 'daily_journal_entry';

  static String _dateToken(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _key(int userId, String date) => '${_prefix}_u${userId}_$date';

  static Future<void> save(int userId, Map<String, dynamic> entry) async {
    final rawDate = entry['entry_date']?.toString();
    final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (parsedDate == null) return;
    final normalized = Map<String, dynamic>.from(entry)
      ..['entry_date'] = _dateToken(parsedDate);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(userId, _dateToken(parsedDate)),
      jsonEncode(normalized),
    );
  }

  static Future<Map<String, dynamic>?> load(
    int userId,
    DateTime date,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(userId, _dateToken(date)));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> loadLatest(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    final prefix = '${_prefix}_u${userId}_';
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList()
      ..sort();
    if (keys.isEmpty) return null;
    final raw = preferences.getString(keys.last);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
