import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class DietCalendarDaySummary {
  const DietCalendarDaySummary({
    required this.mealDate,
    required this.mealCount,
    required this.itemCount,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final DateTime mealDate;
  final int mealCount;
  final int itemCount;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  factory DietCalendarDaySummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return DietCalendarDaySummary(
      mealDate: DateTime.parse(json['meal_date'].toString()),
      mealCount: asInt(json['meal_count']),
      itemCount: asInt(json['item_count']),
      calories: asInt(json['calories']),
      proteinG: asInt(json['protein_g']),
      carbsG: asInt(json['carbs_g']),
      fatG: asInt(json['fat_g']),
    );
  }
}

class DietCalendarService {
  static String _dateParam(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static Future<Map<DateTime, DietCalendarDaySummary>> fetchRange({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final url =
        Uri.parse(
          '${ApiConfig.baseUrl}/diet/meals/$userId/range-summary',
        ).replace(
          queryParameters: {'start': _dateParam(start), 'end': _dateParam(end)},
        );
    final response = await http.get(
      url,
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to load calendar meals (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = <DateTime, DietCalendarDaySummary>{};
    for (final raw in body['days'] as List<dynamic>? ?? const []) {
      if (raw is! Map) continue;
      final summary = DietCalendarDaySummary.fromJson(
        Map<String, dynamic>.from(raw),
      );
      final date = summary.mealDate;
      result[DateTime(date.year, date.month, date.day)] = summary;
    }
    return result;
  }
}
