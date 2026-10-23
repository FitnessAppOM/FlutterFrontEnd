import 'dart:convert';

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
  static String _dateParam(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

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
}
