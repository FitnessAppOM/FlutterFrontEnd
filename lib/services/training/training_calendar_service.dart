import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/base_url.dart';

class TrainingCalendarService {
  static String baseUrl = ApiConfig.baseUrl;

  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  /// Explicitly set a calendar mapping for a date.
  /// Backend will enforce:
  /// - day_type='training' => training_day_id required (>= 1)
  /// - day_type='rest' => training_day_id must be null
  static Future<void> setDay({
    required int userId,
    required DateTime entryDate,
    required String dayType, // 'rest' | 'training'
    int? trainingDayId,
    String source = 'frontend',
  }) async {
    final url = Uri.parse('$baseUrl/training/calendar/$userId');
    final body = <String, dynamic>{
      'entry_date': _dateParam(entryDate),
      'day_type': dayType,
      'source': source,
      if (dayType == 'training') 'training_day_id': trainingDayId,
      if (dayType == 'rest') 'training_day_id': null,
    };
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      final decoded = res.body.isNotEmpty ? json.decode(res.body) : {};
      throw Exception((decoded is Map && decoded['detail'] != null) ? decoded['detail'] : 'Failed to set training calendar');
    }
  }
}

