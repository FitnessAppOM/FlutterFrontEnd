import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class FitbitHeartSummary {
  final int? restingHr;
  final double? hrvRmssd;
  final String? vo2Max;
  final List<dynamic> zones;

  const FitbitHeartSummary({
    required this.restingHr,
    required this.hrvRmssd,
    required this.vo2Max,
    required this.zones,
  });
}

class FitbitHeartService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<FitbitHeartSummary?> fetchSummary(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final heartUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/heart/daily?user_id=$userId&date=$dateStr");
    final hrvUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/hrv?user_id=$userId&date=$dateStr");
    final cardioUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/cardio?user_id=$userId&date=$dateStr");

    final res = await Future.wait([
      http.get(heartUrl),
      http.get(hrvUrl),
      http.get(cardioUrl),
    ]);

    if (res.any((r) => r.statusCode != 200)) {
      throw Exception("Fitbit heart fetch failed");
    }

    final heartData = jsonDecode(res[0].body) as Map<String, dynamic>;
    final hrvData = jsonDecode(res[1].body) as Map<String, dynamic>;
    final cardioData = jsonDecode(res[2].body) as Map<String, dynamic>;

    int? _int(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return FitbitHeartSummary(
      restingHr: _int(heartData["resting_hr"]),
      hrvRmssd: _double(hrvData["daily_rmssd"]),
      vo2Max: cardioData["vo2max"]?.toString(),
      zones: (heartData["zones"] is List) ? (heartData["zones"] as List) : const [],
    );
  }

  Future<Map<String, dynamic>?> fetchIntraday(DateTime date, {String detail = "1min"}) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/fitbit/heart/intraday?user_id=$userId&date=$dateStr&detail=$detail",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }
}
