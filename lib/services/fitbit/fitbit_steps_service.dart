import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';


class FitbitStepsService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<Map<DateTime, int>> fetchDailySteps({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return {};
    final startStr = _dateParam(start);
    final endStr = _dateParam(end);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/steps-range?user_id=$userId&start=$startStr&end=$endStr",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Failed to load Fitbit steps: ${res.body}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final daily = data["daily"] as Map<String, dynamic>? ?? {};
    final out = <DateTime, int>{};
    daily.forEach((key, value) {
      final dt = DateTime.tryParse(key);
      if (dt == null) return;
      final v = value is int ? value : int.tryParse(value.toString()) ?? 0;
      out[DateTime(dt.year, dt.month, dt.day)] = v;
    });
    return out;
  }
}
