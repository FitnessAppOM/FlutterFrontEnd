import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class StravaService {
  static final Map<String, Map<String, dynamic>> _activitiesOverviewCache = {};
  static final Map<String, Future<Map<String, dynamic>>>
  _activitiesOverviewInFlight = {};

  Future<int> _requireUserId() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) {
      throw Exception("Please log in.");
    }
    return userId;
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded["detail"];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {}
    return response.body;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final userId = await _requireUserId();
    final headers = await AccountStorage.getAuthHeaders();
    final qp = <String, String>{"user_id": "$userId", ...?query};
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}$path",
    ).replace(queryParameters: qp);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      final message = _extractErrorMessage(response);
      throw Exception(
        "Strava request failed (${response.statusCode}): $message",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
    return decoded;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    Map<String, String>? query,
  }) async {
    final userId = await _requireUserId();
    final authHeaders = await AccountStorage.getAuthHeaders();
    final headers = <String, String>{
      ...authHeaders,
      "Content-Type": "application/json",
    };
    final qp = <String, String>{"user_id": "$userId", ...?query};
    final uri = Uri.parse(
      "${ApiConfig.baseUrl}$path",
    ).replace(queryParameters: qp);
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      final message = _extractErrorMessage(response);
      throw Exception(
        "Strava request failed (${response.statusCode}): $message",
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
    return decoded;
  }

  Future<Map<String, dynamic>> fetchStatus() {
    return _get("/strava/status");
  }

  static String _activitiesOverviewCacheKey({
    required int userId,
    required int page,
    required int perPage,
    int? activityId,
  }) {
    final selected = activityId ?? 0;
    return "$userId|$page|$perPage|$selected";
  }

  static void _clearActivitiesOverviewCacheForUser(int userId) {
    final prefix = "$userId|";
    final keys = _activitiesOverviewCache.keys
        .where((k) => k.startsWith(prefix))
        .toList(growable: false);
    for (final key in keys) {
      _activitiesOverviewCache.remove(key);
      _activitiesOverviewInFlight.remove(key);
    }
  }

  static void clearActivitiesOverviewCache() {
    _activitiesOverviewCache.clear();
    _activitiesOverviewInFlight.clear();
  }

  Future<Map<String, dynamic>?> getCachedActivitiesOverview({
    int page = 1,
    int perPage = 20,
    int? activityId,
  }) async {
    final userId = await _requireUserId();
    final key = _activitiesOverviewCacheKey(
      userId: userId,
      page: page,
      perPage: perPage,
      activityId: activityId,
    );
    return _activitiesOverviewCache[key];
  }

  Future<Map<String, dynamic>> fetchActivitiesOverview({
    int page = 1,
    int perPage = 20,
    int? activityId,
    bool forceRefresh = false,
  }) async {
    final userId = await _requireUserId();
    final key = _activitiesOverviewCacheKey(
      userId: userId,
      page: page,
      perPage: perPage,
      activityId: activityId,
    );
    if (!forceRefresh && _activitiesOverviewCache.containsKey(key)) {
      return _activitiesOverviewCache[key]!;
    }
    if (!forceRefresh && _activitiesOverviewInFlight.containsKey(key)) {
      return _activitiesOverviewInFlight[key]!;
    }

    final query = <String, String>{
      "page": "$page",
      "per_page": "$perPage",
      if (activityId != null) "activity_id": "$activityId",
    };
    final future = _get("/strava/activities/overview", query: query);
    _activitiesOverviewInFlight[key] = future;
    try {
      final result = await future;
      _activitiesOverviewCache[key] = result;
      return result;
    } finally {
      _activitiesOverviewInFlight.remove(key);
    }
  }

  Future<Map<String, dynamic>> fetchActivitiesLiveSummary({
    int perPage = 200,
    int maxPages = 20,
    bool includeActivities = false,
  }) {
    return _get(
      "/strava/activities/live/summary",
      query: {
        "per_page": "$perPage",
        "max_pages": "$maxPages",
        "include_activities": includeActivities ? "1" : "0",
      },
    );
  }

  Future<Map<String, dynamic>> syncRecentActivities({int perPage = 10}) async {
    final result = await _get(
      "/strava/activities/sync",
      query: {"per_page": "$perPage"},
    );
    final userId = await _requireUserId();
    _clearActivitiesOverviewCacheForUser(userId);
    return result;
  }

  Future<Map<String, dynamic>> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTimeSeconds,
    String? description,
    double? distanceMeters,
  }) async {
    final userId = await _requireUserId();
    final payload = <String, dynamic>{
      "name": name,
      "type": type,
      "start_date_local": startDateLocal,
      "elapsed_time": elapsedTimeSeconds,
      if (description != null && description.trim().isNotEmpty)
        "description": description.trim(),
      if (distanceMeters != null) "distance": distanceMeters,
    };
    final result = await _postJson("/strava/activities/create", payload);
    _clearActivitiesOverviewCacheForUser(userId);
    return result;
  }

  static String formatLocalForStrava(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return "$y-$m-${d}T$hh:$mm:$ss";
  }
}
