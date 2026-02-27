import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class WhoopRecoveryService {
  Map<DateTime, Map<String, dynamic>> _mapDailyFromDb(List<dynamic> data) {
    final out = <DateTime, Map<String, dynamic>>{};
    for (final item in data) {
      if (item is! Map) continue;
      final dateStr = item["entry_date"]?.toString();
      if (dateStr == null) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }
      out[DateTime(dt.year, dt.month, dt.day)] = {
        "recovery_score": item["recovery_score"],
        "rhr": item["resting_hr"],
        "hrv": item["hrv_rmssd"],
        "spo2": item["spo2_percent"],
        "skin_temp_c": item["skin_temp_c"],
        "user_calibrating": null,
      };
    }
    return out;
  }

  Future<Map<DateTime, Map<String, dynamic>>> fetchDailyRecoveryFromDb({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return {};

    final startStr =
        "${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    final endStr =
        "${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/daily-metrics/range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      return {};
    }
    final data = jsonDecode(res.body);
    if (data is! List) return {};
    return _mapDailyFromDb(data);
  }
  Future<Map<DateTime, Map<String, dynamic>>> fetchDailyRecovery({
    required DateTime start,
    required DateTime end,
  }) async {
    final startKey = DateTime(start.year, start.month, start.day);
    final endKey = DateTime(end.year, end.month, end.day);
    return fetchDailyRecoveryFromDb(start: startKey, end: endKey);
  }
}
