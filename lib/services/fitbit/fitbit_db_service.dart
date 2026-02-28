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
}
