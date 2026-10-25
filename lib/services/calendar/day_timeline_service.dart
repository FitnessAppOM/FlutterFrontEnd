import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class DayTimelineEvent {
  const DayTimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.occurredAt,
    required this.details,
  });

  final String id;
  final String type;
  final String title;
  final DateTime? occurredAt;
  final Map<String, dynamic> details;

  factory DayTimelineEvent.fromJson(Map<String, dynamic> json) {
    final rawTime = json['occurred_at']?.toString();
    final parsedTime = rawTime == null ? null : DateTime.tryParse(rawTime);
    return DayTimelineEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'activity',
      title: json['title']?.toString() ?? '',
      occurredAt: parsedTime?.toLocal(),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : const {},
    );
  }
}

class DayTimelineData {
  const DayTimelineData({
    required this.entryDate,
    required this.dailySummary,
    required this.plannedActivity,
    required this.events,
  });

  final DateTime entryDate;
  final Map<String, dynamic>? dailySummary;
  final Map<String, dynamic>? plannedActivity;
  final List<DayTimelineEvent> events;

  factory DayTimelineData.fromJson(Map<String, dynamic> json) {
    return DayTimelineData(
      entryDate: DateTime.parse(json['entry_date'].toString()),
      dailySummary: json['daily_summary'] is Map
          ? Map<String, dynamic>.from(json['daily_summary'] as Map)
          : null,
      plannedActivity: json['planned_activity'] is Map
          ? Map<String, dynamic>.from(json['planned_activity'] as Map)
          : null,
      events: (json['events'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                DayTimelineEvent.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class DayTimelineService {
  static final Random _random = Random.secure();

  static String _dateParam(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _timestampWithOffset(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '${local.toIso8601String()}$sign$hours:$minutes';
  }

  static Future<DayTimelineData> fetch({
    required int userId,
    required DateTime date,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/calendar/$userId/day',
    ).replace(queryParameters: {'entry_date': _dateParam(date)});
    final response = await http.get(
      uri,
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to load day timeline (${response.statusCode})');
    }
    return DayTimelineData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static String newEntryKey(int userId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(0x7fffffff);
    return 'calendar-$userId-$now-$random';
  }

  static Future<Map<String, dynamic>> createMeal({
    required int userId,
    required DateTime scheduledAt,
    required String title,
    required List<Map<String, dynamic>> items,
    String? notes,
    required String entryKey,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/calendar/$userId/meals');
    final localScheduledAt = scheduledAt.isUtc
        ? scheduledAt.toLocal()
        : scheduledAt;
    final response = await http.post(
      uri,
      headers: {
        ...await AccountStorage.getAuthHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scheduled_date': _dateParam(localScheduledAt),
        'scheduled_at': _timestampWithOffset(localScheduledAt),
        'title': title,
        'notes': notes,
        'items': items,
        'entry_key': entryKey,
      }),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to save meal'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> createPhotoMeal({
    required int userId,
    required DateTime scheduledAt,
    required List<int> photoBytes,
    required String filename,
    String? textDescription,
    required String entryKey,
  }) async {
    final localScheduledAt = scheduledAt.isUtc
        ? scheduledAt.toLocal()
        : scheduledAt;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/calendar/$userId/meals/photo'),
    );
    request.headers.addAll(await AccountStorage.getAuthHeaders());
    request.fields.addAll({
      'scheduled_date': _dateParam(localScheduledAt),
      'scheduled_at': _timestampWithOffset(localScheduledAt),
      'entry_key': entryKey,
      if (textDescription?.trim().isNotEmpty == true)
        'text_description': textDescription!.trim(),
    });
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to save meal'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> markMealPlanEaten({
    required int userId,
    required int planId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/calendar/$userId/meal-plans/$planId/complete',
    );
    final response = await http.post(
      uri,
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to log planned meal'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> updateMealPlan({
    required int userId,
    required int planId,
    required String title,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/calendar/$userId/meal-plans/$planId'),
      headers: {
        ...await AccountStorage.getAuthHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title, 'items': items}),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to update meal plan'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<void> deleteMealPlan({
    required int userId,
    required int planId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/calendar/$userId/meal-plans/$planId'),
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to delete meal plan'));
    }
  }

  static Future<Map<String, dynamic>> appendPhotoToMealPlan({
    required int userId,
    required int planId,
    required List<int> photoBytes,
    required String filename,
    String? textDescription,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/calendar/$userId/meal-plans/$planId/items/photo',
      ),
    );
    request.headers.addAll(await AccountStorage.getAuthHeaders());
    if (textDescription?.trim().isNotEmpty == true) {
      request.fields['text_description'] = textDescription!.trim();
    }
    request.files.add(
      http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
    );
    final response = await http.Response.fromStream(await request.send());
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'Failed to update meal plan'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static String _responseError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'].toString().trim();
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {
      // Use the stable fallback below.
    }
    return '$fallback (${response.statusCode})';
  }
}
