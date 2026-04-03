import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class StravaService {
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

  Future<Map<String, dynamic>> fetchAthleteOverview() {
    return _get("/strava/athlete/overview");
  }

  Future<Map<String, dynamic>> fetchStatus() {
    return _get("/strava/status");
  }

  Future<Map<String, dynamic>> fetchActivitiesOverview({
    int page = 1,
    int perPage = 20,
    int? activityId,
  }) {
    final query = <String, String>{
      "page": "$page",
      "per_page": "$perPage",
      if (activityId != null) "activity_id": "$activityId",
    };
    return _get("/strava/activities/overview", query: query);
  }

  Future<Map<String, dynamic>> fetchNetworkOverview({
    int page = 1,
    int perPage = 20,
  }) {
    final query = <String, String>{"page": "$page", "per_page": "$perPage"};
    return _get("/strava/network/overview", query: query);
  }

  Future<Map<String, dynamic>> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTimeSeconds,
    String? description,
    double? distanceMeters,
  }) {
    final payload = <String, dynamic>{
      "name": name,
      "type": type,
      "start_date_local": startDateLocal,
      "elapsed_time": elapsedTimeSeconds,
      if (description != null && description.trim().isNotEmpty)
        "description": description.trim(),
      if (distanceMeters != null) "distance": distanceMeters,
    };
    return _postJson("/strava/activities/create", payload);
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
