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
      String msg = 'Failed to load habits';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
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
}
