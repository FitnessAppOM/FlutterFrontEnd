import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class DailyOutlookData {
  final int userId;
  final DateTime entryDate;
  final DateTime sourceDate;
  final String? provider;
  final String generationPath;
  final String readinessState;
  final String headline;
  final String summary;
  final List<String> actionItems;
  final String cautionNote;
  final DateTime? generatedAt;

  const DailyOutlookData({
    required this.userId,
    required this.entryDate,
    required this.sourceDate,
    required this.generationPath,
    required this.readinessState,
    required this.headline,
    required this.summary,
    required this.actionItems,
    required this.cautionNote,
    this.provider,
    this.generatedAt,
  });

  factory DailyOutlookData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['action_items'];
    final items = rawItems is List
        ? rawItems
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return DailyOutlookData(
      userId: (json['user_id'] as num).toInt(),
      entryDate: DateTime.parse(json['entry_date'] as String),
      sourceDate: DateTime.parse(json['source_date'] as String),
      provider: json['provider'] as String?,
      generationPath: (json['generation_path'] as String?) ?? 'non_wearable',
      readinessState: (json['readiness_state'] as String?) ?? '',
      headline: (json['headline'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      actionItems: items,
      cautionNote: (json['caution_note'] as String?) ?? '',
      generatedAt: json['generated_at'] is String
          ? DateTime.tryParse(json['generated_at'] as String)
          : null,
    );
  }
}

class DailyOutlookStatus {
  final int userId;
  final DateTime entryDate;
  final bool generated;
  final bool locked;
  final bool generatedNow;
  final DailyOutlookData? outlook;

  const DailyOutlookStatus({
    required this.userId,
    required this.entryDate,
    required this.generated,
    required this.locked,
    required this.generatedNow,
    this.outlook,
  });

  factory DailyOutlookStatus.fromJson(Map<String, dynamic> json) {
    final outlookJson = json['outlook'];
    return DailyOutlookStatus(
      userId: (json['user_id'] as num).toInt(),
      entryDate: DateTime.parse(json['entry_date'] as String),
      generated: json['generated'] == true,
      locked: json['locked'] == true,
      generatedNow: json['generated_now'] == true,
      outlook: outlookJson is Map<String, dynamic>
          ? DailyOutlookData.fromJson(outlookJson)
          : null,
    );
  }
}

class DailyOutlookApi {
  static final Map<String, DailyOutlookStatus?> _cache = {};
  static final Map<String, Future<DailyOutlookStatus?>> _inFlight = {};

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static String _dayKey(int userId, DateTime date) =>
      "$userId|${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  static String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static Future<DailyOutlookStatus?> fetchDaily({
    required int userId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final key = _dayKey(userId, date);
    if (!forceRefresh && _cache.containsKey(key)) return _cache[key];
    if (_inFlight.containsKey(key)) return _inFlight[key];

    final future = _doFetchDaily(userId, date, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<DailyOutlookStatus?> _doFetchDaily(
    int userId,
    DateTime date,
    String cacheKey,
  ) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (headers.isEmpty) return null;

    final dateStr = _fmtDate(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/daily-outlook/$userId/daily?date=$dateStr",
    );

    try {
      final resp = await http.get(url, headers: headers);
      final handled = await AccountStorage.handleAuthStatus(
        resp.statusCode,
        responseBody: resp.body,
      );
      if (handled) return null;
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return null;
      final status = DailyOutlookStatus.fromJson(json);
      _cache[cacheKey] = status;
      return status;
    } catch (_) {
      return null;
    }
  }

  static Future<DailyOutlookStatus?> generateDaily({
    required int userId,
    required DateTime date,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    if (!headers.containsKey("Authorization")) return null;

    final dateStr = _fmtDate(date);
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/daily-outlook/$userId/generate?date=$dateStr",
    );

    final resp = await http.post(url, headers: headers);
    final handled = await AccountStorage.handleAuthStatus(
      resp.statusCode,
      responseBody: resp.body,
    );
    if (handled) return null;
    if (resp.statusCode != 200) {
      String message = "Failed to generate Daily Outlook.";
      try {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic> && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("Invalid Daily Outlook response.");
    }
    final status = DailyOutlookStatus.fromJson(decoded);
    _cache[_dayKey(userId, date)] = status;
    return status;
  }
}
