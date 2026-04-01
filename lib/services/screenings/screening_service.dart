import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ScreeningPendingResult {
  final bool isDue;
  final String reason;
  final String? windowOpenedAt;
  final String? windowClosesAt;
  final int? daysRemaining;
  final String? nextDueDate;

  const ScreeningPendingResult({
    required this.isDue,
    required this.reason,
    this.windowOpenedAt,
    this.windowClosesAt,
    this.daysRemaining,
    this.nextDueDate,
  });

  factory ScreeningPendingResult.fromJson(Map<String, dynamic> json) {
    return ScreeningPendingResult(
      isDue: json['is_due'] == true,
      reason: json['reason'] as String? ?? 'not_due_yet',
      windowOpenedAt: json['window_opened_at'] as String?,
      windowClosesAt: json['window_closes_at'] as String?,
      daysRemaining: json['days_remaining'] is num
          ? (json['days_remaining'] as num).toInt()
          : null,
      nextDueDate: json['next_due_date'] as String?,
    );
  }

  static const notDue = ScreeningPendingResult(
    isDue: false,
    reason: 'not_due_yet',
  );
}

class ScreeningSubmitResult {
  final String message;
  final int? screeningId;
  final String? eq5dHealthState;
  final int? phq2Total;
  final String? createdAt;

  const ScreeningSubmitResult({
    required this.message,
    this.screeningId,
    this.eq5dHealthState,
    this.phq2Total,
    this.createdAt,
  });

  factory ScreeningSubmitResult.fromJson(Map<String, dynamic> json) {
    return ScreeningSubmitResult(
      message: json['message'] as String? ?? '',
      screeningId:
          json['screening_id'] is num
              ? (json['screening_id'] as num).toInt()
              : null,
      eq5dHealthState: json['eq5d_health_state'] as String?,
      phq2Total:
          json['phq2_total'] is num
              ? (json['phq2_total'] as num).toInt()
              : null,
      createdAt: json['created_at'] as String?,
    );
  }
}

class ScreeningHistoryEntry {
  final int? screeningId;
  final int? userId;
  final int mobility;
  final int selfCare;
  final int usualActivities;
  final int painDiscomfort;
  final int anxietyDepression;
  final int q1Interest;
  final int q2Mood;
  final String? eq5dHealthState;
  final int? phq2Total;
  final String? createdAt;

  const ScreeningHistoryEntry({
    this.screeningId,
    this.userId,
    required this.mobility,
    required this.selfCare,
    required this.usualActivities,
    required this.painDiscomfort,
    required this.anxietyDepression,
    required this.q1Interest,
    required this.q2Mood,
    this.eq5dHealthState,
    this.phq2Total,
    this.createdAt,
  });

  factory ScreeningHistoryEntry.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : 0;
    return ScreeningHistoryEntry(
      screeningId:
          json['screening_id'] is num
              ? (json['screening_id'] as num).toInt()
              : null,
      userId:
          json['user_id'] is num ? (json['user_id'] as num).toInt() : null,
      mobility: toInt(json['mobility']),
      selfCare: toInt(json['self_care']),
      usualActivities: toInt(json['usual_activities']),
      painDiscomfort: toInt(json['pain_discomfort']),
      anxietyDepression: toInt(json['anxiety_depression']),
      q1Interest: toInt(json['q1_interest']),
      q2Mood: toInt(json['q2_mood']),
      eq5dHealthState: json['eq5d_health_state'] as String?,
      phq2Total:
          json['phq2_total'] is num
              ? (json['phq2_total'] as num).toInt()
              : null,
      createdAt: json['created_at'] as String?,
    );
  }
}

class ScreeningApi {
  static Future<ScreeningPendingResult> checkPending(int userId) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) return ScreeningPendingResult.notDue;

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/screenings/$userId/pending",
    );

    try {
      final resp = await http.get(url, headers: headers);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await AccountStorage.handleAuthStatus(
          resp.statusCode,
          responseBody: resp.body,
        );
        return ScreeningPendingResult.notDue;
      }
      if (resp.statusCode != 200) return ScreeningPendingResult.notDue;

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return ScreeningPendingResult.notDue;
      return ScreeningPendingResult.fromJson(json);
    } catch (_) {
      return ScreeningPendingResult.notDue;
    }
  }

  /// Returns the submit result on success.
  /// Throws [ScreeningConflictException] if the screening was already
  /// submitted for this cycle (409). Other failures throw a generic
  /// [Exception].
  static Future<ScreeningSubmitResult> submit({
    required int userId,
    required int mobility,
    required int selfCare,
    required int usualActivities,
    required int painDiscomfort,
    required int anxietyDepression,
    required int q1Interest,
    required int q2Mood,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/screenings/$userId/submit",
    );

    final body = jsonEncode({
      "user_id": userId,
      "mobility": mobility,
      "self_care": selfCare,
      "usual_activities": usualActivities,
      "pain_discomfort": painDiscomfort,
      "anxiety_depression": anxietyDepression,
      "q1_interest": q1Interest,
      "q2_mood": q2Mood,
    });

    final resp = await http.post(url, headers: headers, body: body);

    await AccountStorage.handle401(resp.statusCode);

    if (resp.statusCode == 409) {
      throw const ScreeningConflictException();
    }
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final json = jsonDecode(resp.body);
      if (json is Map<String, dynamic>) {
        return ScreeningSubmitResult.fromJson(json);
      }
    }
    throw Exception("Failed to submit screening: ${resp.body}");
  }

  static Future<List<ScreeningHistoryEntry>> fetchHistory(
    int userId, {
    int limit = 10,
  }) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) return const [];

    final url = Uri.parse(
      "${ApiConfig.baseUrl}/screenings/$userId/history?limit=$limit",
    );

    try {
      final resp = await http.get(url, headers: headers);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await AccountStorage.handleAuthStatus(
          resp.statusCode,
          responseBody: resp.body,
        );
        return const [];
      }
      if (resp.statusCode != 200) return const [];

      final json = jsonDecode(resp.body);
      if (json is! List) return const [];
      return json
          .whereType<Map<String, dynamic>>()
          .map(ScreeningHistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class ScreeningConflictException implements Exception {
  const ScreeningConflictException();
  @override
  String toString() => 'already_submitted';
}
