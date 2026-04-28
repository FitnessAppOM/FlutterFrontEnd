import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class CoachHabitReminderSettings {
  const CoachHabitReminderSettings({
    required this.autoEnabled,
    required this.scheduleType,
    required this.weeklyDay,
    required this.hourOfDay,
    required this.usesServerTime,
    required this.timeZone,
  });

  final bool autoEnabled;
  final String? scheduleType;
  final int weeklyDay;
  final int hourOfDay;
  final bool usesServerTime;
  final String timeZone;

  CoachHabitReminderSettings copyWith({
    bool? autoEnabled,
    String? scheduleType,
    int? weeklyDay,
    int? hourOfDay,
    bool? usesServerTime,
    String? timeZone,
  }) {
    return CoachHabitReminderSettings(
      autoEnabled: autoEnabled ?? this.autoEnabled,
      scheduleType: scheduleType ?? this.scheduleType,
      weeklyDay: weeklyDay ?? this.weeklyDay,
      hourOfDay: hourOfDay ?? this.hourOfDay,
      usesServerTime: usesServerTime ?? this.usesServerTime,
      timeZone: timeZone ?? this.timeZone,
    );
  }

  factory CoachHabitReminderSettings.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final scheduleRaw = (json['schedule_type'] ?? '').toString().trim();
    final schedule = scheduleRaw.isEmpty ? null : scheduleRaw;
    return CoachHabitReminderSettings(
      autoEnabled: json['auto_enabled'] == true,
      scheduleType: schedule,
      weeklyDay: parseInt(json['weekly_day'], 0).clamp(0, 6),
      hourOfDay: parseInt(json['hour_of_day'], 9).clamp(0, 23),
      usesServerTime: json['uses_server_time'] != false,
      timeZone: (json['time_zone'] ?? 'UTC').toString().trim().isEmpty
          ? 'UTC'
          : (json['time_zone'] ?? 'UTC').toString().trim(),
    );
  }
}

class CoachHabitReminderSettingsService {
  static String _errorMessage(String responseBody, String fallback) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data['detail'] != null) {
        final raw = data['detail'].toString().trim();
        if (raw.isNotEmpty) return raw;
      }
    } catch (_) {}
    return fallback;
  }

  static Future<CoachHabitReminderSettings> fetchSettings() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/coach/habit-reminder-settings');
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(uri, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to load reminder settings'));
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    return CoachHabitReminderSettings.fromJson(data);
  }

  static Future<CoachHabitReminderSettings> updateSettings({
    required bool autoEnabled,
    required String? scheduleType,
    required int weeklyDay,
    required int hourOfDay,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/coach/habit-reminder-settings');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final payload = <String, dynamic>{
      'auto_enabled': autoEnabled,
      'schedule_type': autoEnabled ? scheduleType : null,
      'weekly_day': autoEnabled && scheduleType == 'weekly' ? weeklyDay : null,
      'hour_of_day': autoEnabled ? hourOfDay : null,
    };
    final res = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to save reminder settings'));
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    return CoachHabitReminderSettings.fromJson(data);
  }

  static Future<Map<String, dynamic>> triggerNow() async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/coach/habit-reminder-settings/trigger-now',
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.post(uri, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to trigger reminders'));
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    return data;
  }
}
