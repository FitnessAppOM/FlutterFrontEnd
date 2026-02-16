import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class WhoopLatestService {
  static Map<String, dynamic>? _cache;
  static DateTime? _fetchedAt;
  static Future<Map<String, dynamic>?>? _inFlight;

  static Future<Map<String, dynamic>?> fetch({int ttlSeconds = 30}) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;

    final now = DateTime.now();
    if (_cache != null && _fetchedAt != null) {
      final age = now.difference(_fetchedAt!);
      if (age.inSeconds < ttlSeconds) {
        return _cache;
      }
    }
    if (_inFlight != null) return _inFlight;

    final url = Uri.parse("${ApiConfig.baseUrl}/whoop/latest?user_id=$userId");
    final headers = await AccountStorage.getAuthHeaders();
    final future = http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 20))
        .then((res) {
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _cache = data;
      _fetchedAt = DateTime.now();
      return data;
    });
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  static void clear() {
    _cache = null;
    _fetchedAt = null;
    _inFlight = null;
  }
}
