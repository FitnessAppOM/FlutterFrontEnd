import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class CoachHabitItem {
  final int id;
  final int expertId;
  final int clientId;
  final String habit;
  final bool isCompleted;
  final DateTime? addedAt;
  final DateTime? completedAt;

  const CoachHabitItem({
    required this.id,
    required this.expertId,
    required this.clientId,
    required this.habit,
    required this.isCompleted,
    this.addedAt,
    this.completedAt,
  });

  CoachHabitItem copyWith({
    int? id,
    int? expertId,
    int? clientId,
    String? habit,
    bool? isCompleted,
    DateTime? addedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return CoachHabitItem(
      id: id ?? this.id,
      expertId: expertId ?? this.expertId,
      clientId: clientId ?? this.clientId,
      habit: habit ?? this.habit,
      isCompleted: isCompleted ?? this.isCompleted,
      addedAt: addedAt ?? this.addedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  factory CoachHabitItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final raw = v.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return CoachHabitItem(
      id: parseInt(json['id']),
      expertId: parseInt(json['expert_id']),
      clientId: parseInt(json['client_id']),
      habit: (json['habit'] ?? '').toString(),
      isCompleted: json['is_completed'] == true,
      addedAt: parseDate(json['added_at']),
      completedAt: parseDate(json['completed_at']),
    );
  }
}

class CoachHabitsService {
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

  static Future<List<CoachHabitItem>> fetchClientHabits({
    required int clientId,
    int? expertId,
    bool includeCompleted = true,
  }) async {
    final query = <String, String>{
      'include_completed': includeCompleted ? 'true' : 'false',
      if (expertId != null) 'expert_id': '$expertId',
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/coach/habits/$clientId',
    ).replace(queryParameters: query);

    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(uri, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to load habits'));
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return [];
    final rawItems = data['items'];
    if (rawItems is! List) return [];
    return rawItems
        .whereType<Map>()
        .map((e) => CoachHabitItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<CoachHabitItem> setHabitCompletion({
    required int habitId,
    required bool isCompleted,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/coach/habits/item/$habitId');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode({'is_completed': isCompleted}),
    );
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to update habit'));
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    final rawItem = data['item'];
    if (rawItem is! Map) {
      throw Exception('Invalid response');
    }
    return CoachHabitItem.fromJson(Map<String, dynamic>.from(rawItem));
  }

  static Future<CoachHabitItem> addClientHabit({
    required int clientId,
    required String habit,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/coach/habits');
    final headers = {
      'Content-Type': 'application/json',
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'client_id': clientId, 'habit': habit}),
    );
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to add habit'));
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    final rawItem = data['item'];
    if (rawItem is! Map) {
      throw Exception('Invalid response');
    }
    return CoachHabitItem.fromJson(Map<String, dynamic>.from(rawItem));
  }

  static Future<void> deleteClientHabit({required int habitId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/coach/habits/item/$habitId');
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.delete(uri, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, 'Failed to delete habit'));
    }
  }
}
