import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class FitbitBodySummary {
  final double? weightKg;

  const FitbitBodySummary({
    required this.weightKg,
  });

  bool get hasAny => weightKg != null;
}

class FitbitBodyService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  Future<FitbitBodySummary?> fetchSummary(DateTime date) async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final headers = await AccountStorage.getAuthHeaders();

    final weightUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/body/weight?user_id=$userId&date=$dateStr");
    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    Future<Map<String, dynamic>?> _safeGet(Uri url) async {
      try {
        final res = await http.get(url, headers: headers);
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      } catch (_) {
        return null;
      }
    }

    final weightData = await _safeGet(weightUrl);

    double? weightKg;
    final weightLogs = weightData?['weight'];
    if (weightLogs is List && weightLogs.isNotEmpty) {
      final entry = weightLogs.first;
      if (entry is Map) {
        weightKg = _double(entry['weight']);
      }
    }

    final summary = FitbitBodySummary(weightKg: weightKg);
    return summary.hasAny ? summary : null;
  }
}
