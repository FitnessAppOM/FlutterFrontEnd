import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import '../core/account_storage.dart';

class WhoopRecoveryService {
  Future<Map<DateTime, Map<String, dynamic>>> fetchDailyRecovery({
    required DateTime start,
    required DateTime end,
  }) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return {};

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/whoop/recovery-daily?user_id=$userId"
      "&start=${Uri.encodeComponent(start.toIso8601String())}"
      "&end=${Uri.encodeComponent(end.toIso8601String())}",
    );
    final res = await http.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception("Status ${res.statusCode}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data["daily"];
    if (raw is! Map<String, dynamic>) return {};

    final Map<DateTime, Map<String, dynamic>> result = {};
    raw.forEach((k, v) {
      final dt = DateTime.tryParse(k);
      if (dt != null && v is Map<String, dynamic>) {
        result[DateTime(dt.year, dt.month, dt.day)] = v;
      }
    });
    return result;
  }
}
