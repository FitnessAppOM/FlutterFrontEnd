import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class FitbitDailyMetricsDbService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<Map<String, dynamic>?> fetchRow(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$dateStr&end=$dateStr",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! List || data.isEmpty) return null;
    final row = data.first;
    return row is Map<String, dynamic> ? row : null;
  }

  Future<Map<DateTime, Map<String, dynamic>>> fetchRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return {};
    final startStr = _dateParam(start);
    final endStr = _dateParam(end);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode != 200) return {};
    final data = jsonDecode(res.body);
    if (data is! List) return {};
    final out = <DateTime, Map<String, dynamic>>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final rawDate = item["entry_date"];
      DateTime? dt;
      if (rawDate is DateTime) {
        dt = rawDate;
      } else if (rawDate != null) {
        dt = DateTime.tryParse(rawDate.toString());
      }
      if (dt == null) continue;
      final key = DateTime(dt.year, dt.month, dt.day);
      out[key] = item;
    }
    return out;
  }
}
