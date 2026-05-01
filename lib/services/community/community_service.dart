import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'community_models.dart';

class CommunityApiException implements Exception {
  CommunityApiException(this.statusCode, this.detail);

  final int statusCode;
  final String detail;

  @override
  String toString() => detail;
}

class CommunityService {
  static String baseUrl = ApiConfig.baseUrl;

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final rawBase = baseUrl.trim();
    final normalizedBase = rawBase.endsWith('/') ? rawBase : '$rawBase/';
    final uri = Uri.parse(normalizedBase).resolve(path.startsWith('/') ? path.substring(1) : path);
    if (query == null || query.isEmpty) return uri;
    final qp = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      qp[entry.key] = text;
    }
    return uri.replace(queryParameters: qp.isEmpty ? null : qp);
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static List<dynamic> _decodeList(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const [];
  }

  static String _extractError(String fallback, http.Response response) {
    final payload = _decodeMap(response.body);
    final detail = payload['detail']?.toString().trim();
    if (detail != null && detail.isNotEmpty) return detail;
    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return '$fallback (${response.statusCode})';
  }

  static Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      ...await AccountStorage.getAuthHeaders(),
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    final uri = _uri(path, query);
    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        );
        break;
      case 'DELETE':
        response = body == null
            ? await http.delete(uri, headers: headers)
            : await http.delete(uri, headers: headers, body: jsonEncode(body));
        break;
      default:
        throw UnsupportedError('Unsupported method $method');
    }
    await AccountStorage.handleAuthStatus(
      response.statusCode,
      responseBody: response.body,
    );
    return response;
  }

  static CommunityPagedResult<T> _parsePaged<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
    String fallback,
  ) {
    if (response.statusCode != 200) {
      throw CommunityApiException(response.statusCode, _extractError(fallback, response));
    }
    final payload = _decodeMap(response.body);
    final items = (payload['items'] as List?)
            ?.map((item) => parser(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false) ??
        List<T>.empty(growable: false);
    final cursorRaw = payload['next_cursor'];
    return CommunityPagedResult<T>(
      items: items,
      nextCursor: cursorRaw == null ? null : int.tryParse(cursorRaw.toString()),
    );
  }

  static Future<CommunityBootstrap> fetchBootstrap() async {
    final response = await _send('GET', '/community/bootstrap');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load community bootstrap', response),
      );
    }
    return CommunityBootstrap.fromJson(_decodeMap(response.body));
  }

  static Future<CommunityPagedResult<CommunityFeedItem>> fetchFeed({
    int? groupId,
    int? cursor,
    int limit = 20,
  }) async {
    final response = await _send(
      'GET',
      '/community/feed',
      query: {
        if (groupId != null) 'group_id': groupId,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _parsePaged(
      response,
      CommunityFeedItem.fromJson,
      'Failed to load community feed',
    );
  }

  static Future<void> likeFeedItem(int feedItemId) async {
    final response = await _send('POST', '/community/feed/$feedItemId/like');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to like feed item', response),
      );
    }
  }

  static Future<void> unlikeFeedItem(int feedItemId) async {
    final response = await _send('DELETE', '/community/feed/$feedItemId/like');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to unlike feed item', response),
      );
    }
  }

  static Future<CommunityPagedResult<CommunityComment>> fetchComments(
    int feedItemId, {
    int? cursor,
    int limit = 20,
  }) async {
    final response = await _send(
      'GET',
      '/community/feed/$feedItemId/comments',
      query: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _parsePaged(
      response,
      CommunityComment.fromJson,
      'Failed to load comments',
    );
  }

  static Future<CommunityComment> createComment(
    int feedItemId,
    String commentText,
  ) async {
    final response = await _send(
      'POST',
      '/community/feed/$feedItemId/comments',
      body: {'comment_text': commentText},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to add comment', response),
      );
    }
    final refreshed = await fetchComments(feedItemId, limit: 1);
    if (refreshed.items.isEmpty) {
      throw CommunityApiException(500, 'Comment was created but could not be reloaded');
    }
    return refreshed.items.first;
  }

  static Future<void> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? details,
  }) async {
    final response = await _send(
      'POST',
      '/community/reports',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'details': details,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to submit report', response),
      );
    }
  }

  static Future<List<CommunityGroupSummary>> fetchMyGroups() async {
    final response = await _send('GET', '/community/groups');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load groups', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityGroupSummary.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<CommunityPagedResult<CommunityGroupSummary>> discoverGroups({
    String? query,
    String? groupKind,
    int? cursor,
    int limit = 20,
  }) async {
    final response = await _send(
      'GET',
      '/community/groups/discover',
      query: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (groupKind != null && groupKind.trim().isNotEmpty) 'group_kind': groupKind.trim(),
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return _parsePaged(
      response,
      CommunityGroupSummary.fromJson,
      'Failed to discover groups',
    );
  }

  static Future<CommunityGroupDetail> fetchGroupDetail(int groupId) async {
    final response = await _send('GET', '/community/groups/$groupId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load group', response),
      );
    }
    return CommunityGroupDetail.fromJson(_decodeMap(response.body));
  }

  static Future<CommunityGroupCreationResult> createGroup({
    required String name,
    required String visibility,
    String? description,
    String? iconPath,
    String groupKind = 'general',
    bool? isDiscoverable,
  }) async {
    final response = await _send(
      'POST',
      '/community/groups',
      body: {
        'name': name,
        'description': description,
        'icon_path': iconPath,
        'visibility': visibility,
        'group_kind': groupKind,
        'is_discoverable': isDiscoverable,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to create group', response),
      );
    }
    return CommunityGroupCreationResult.fromJson(_decodeMap(response.body));
  }

  static Future<CommunityGroupSummary> joinGroupByCode(String code) async {
    final response = await _send(
      'POST',
      '/community/groups/join-by-code',
      body: {'code': code},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to join group', response),
      );
    }
    return CommunityGroupSummary.fromJson(_decodeMap(response.body)['group'] as Map<String, dynamic>);
  }

  static Future<CommunityGroupSummary> joinPublicGroup(int groupId) async {
    final response = await _send('POST', '/community/groups/$groupId/join');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to join group', response),
      );
    }
    return CommunityGroupSummary.fromJson(_decodeMap(response.body)['group'] as Map<String, dynamic>);
  }

  static Future<void> leaveGroup(int groupId) async {
    final response = await _send('POST', '/community/groups/$groupId/leave');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to leave group', response),
      );
    }
  }

  static Future<CommunityShareSettings> fetchShareSettings(int groupId) async {
    final response = await _send('GET', '/community/groups/$groupId/share-settings');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load share settings', response),
      );
    }
    return CommunityShareSettings.fromJson(_decodeMap(response.body));
  }

  static Future<CommunityShareSettings> updateShareSettings(
    int groupId,
    CommunityShareSettings settings,
  ) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId/share-settings',
      body: settings.toJson(),
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update share settings', response),
      );
    }
    return CommunityShareSettings.fromJson(_decodeMap(response.body));
  }

  static Future<void> updateGroupNotifications(
    int groupId, {
    required bool mutedNotifications,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId/notifications',
      body: {'muted_notifications': mutedNotifications},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update group notifications', response),
      );
    }
  }

  static Future<List<CommunityMembership>> fetchGroupMembers(int groupId) async {
    final response = await _send('GET', '/community/groups/$groupId/members');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load members', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityMembership.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<CommunityGroupSummary> updateGroup(
    int groupId, {
    String? name,
    String? description,
    String? iconPath,
    String? visibility,
    String? groupKind,
    bool? isDiscoverable,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId',
      body: {
        'name': name,
        'description': description,
        'icon_path': iconPath,
        'visibility': visibility,
        'group_kind': groupKind,
        'is_discoverable': isDiscoverable,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update group', response),
      );
    }
    return CommunityGroupSummary.fromJson(
      Map<String, dynamic>.from(_decodeMap(response.body)['group'] as Map),
    );
  }

  static Future<String> regenerateJoinCode(int groupId) async {
    final response = await _send('POST', '/community/groups/$groupId/code/reset');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to reset join code', response),
      );
    }
    return _decodeMap(response.body)['join_code']?.toString() ?? '';
  }

  static Future<String> fetchGroupJoinCode(int groupId) async {
    final response = await _send('GET', '/community/groups/$groupId/join-code');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load join code', response),
      );
    }
    return _decodeMap(response.body)['join_code']?.toString() ?? '';
  }

  static Future<void> transferAdmin(int groupId, int newAdminUserId) async {
    final response = await _send(
      'POST',
      '/community/groups/$groupId/admin-transfer',
      body: {'new_admin_user_id': newAdminUserId},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to transfer admin', response),
      );
    }
  }

  static Future<void> removeGroupMember(int groupId, int userId) async {
    final response = await _send('DELETE', '/community/groups/$groupId/members/$userId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to remove member', response),
      );
    }
  }

  static Future<void> updateGroupMemberRole(
    int groupId,
    int userId, {
    required String role,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId/members/$userId/role',
      body: {'role': role},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update member role', response),
      );
    }
  }

  static Future<void> archiveGroup(int groupId) async {
    final response = await _send('DELETE', '/community/groups/$groupId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to archive group', response),
      );
    }
  }

  static Future<List<CommunityPin>> fetchPins(int groupId) async {
    final response = await _send('GET', '/community/groups/$groupId/pins');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load pins', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityPin.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<CommunityPin> createPin(
    int groupId, {
    required String pinType,
    required String title,
    required String body,
    String? expiresAtIso,
    int sortOrder = 0,
  }) async {
    final response = await _send(
      'POST',
      '/community/groups/$groupId/pins',
      body: {
        'pin_type': pinType,
        'title': title,
        'body': body,
        'expires_at': expiresAtIso,
        'sort_order': sortOrder,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to create pin', response),
      );
    }
    return CommunityPin.fromJson(
      Map<String, dynamic>.from(_decodeMap(response.body)['pin'] as Map),
    );
  }

  static Future<CommunityPin> updatePin(
    int groupId,
    int pinId, {
    String? title,
    String? body,
    String? expiresAtIso,
    int? sortOrder,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId/pins/$pinId',
      body: {
        'title': title,
        'body': body,
        'expires_at': expiresAtIso,
        'sort_order': sortOrder,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update pin', response),
      );
    }
    return CommunityPin.fromJson(
      Map<String, dynamic>.from(_decodeMap(response.body)['pin'] as Map),
    );
  }

  static Future<void> deletePin(int groupId, int pinId) async {
    final response = await _send('DELETE', '/community/groups/$groupId/pins/$pinId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to delete pin', response),
      );
    }
  }

  static Future<CommunityLeaderboard> fetchLeaderboard(
    int groupId, {
    String? metric,
  }) async {
    final response = await _send(
      'GET',
      '/community/groups/$groupId/leaderboard',
      query: {if (metric != null) 'metric': metric},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load leaderboard', response),
      );
    }
    return CommunityLeaderboard.fromJson(_decodeMap(response.body));
  }

  static Future<void> updateLeaderboardMetric(
    int groupId,
    String metric,
  ) async {
    final response = await _send(
      'PATCH',
      '/community/groups/$groupId/leaderboard-metric',
      body: {'leaderboard_metric': metric},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update leaderboard metric', response),
      );
    }
  }

  static Future<List<CommunityChallenge>> fetchChallenges({int? groupId}) async {
    final response = await _send(
      'GET',
      groupId == null ? '/community/challenges' : '/community/groups/$groupId/challenges',
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load challenges', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityChallenge.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<CommunityChallenge> fetchChallenge(int challengeId) async {
    final response = await _send('GET', '/community/challenges/$challengeId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load challenge', response),
      );
    }
    return CommunityChallenge.fromJson(_decodeMap(response.body));
  }

  static Future<void> updateChallengeNotifications(
    int challengeId, {
    required bool muted,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/challenges/$challengeId/notifications',
      body: {'muted': muted},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update challenge notifications', response),
      );
    }
  }

  static Future<void> createChallenge({
    required String name,
    required String challengeType,
    required String startAtIso,
    required String endAtIso,
    String? description,
    double? goalValue,
    String? progressUnit,
    bool isActive = true,
  }) async {
    final response = await _send(
      'POST',
      '/community/admin/challenges',
      body: {
        'name': name,
        'description': description,
        'challenge_type': challengeType,
        'start_at': startAtIso,
        'end_at': endAtIso,
        'goal_value': goalValue,
        'progress_unit': progressUnit,
        'is_active': isActive,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to create challenge', response),
      );
    }
  }

  static Future<void> createGroupChallenge(
    int groupId, {
    required String name,
    required String challengeType,
    required String startAtIso,
    required String endAtIso,
    String? description,
    double? goalValue,
    String? progressUnit,
    bool isActive = true,
  }) async {
    final response = await _send(
      'POST',
      '/community/groups/$groupId/challenges',
      body: {
        'name': name,
        'description': description,
        'challenge_type': challengeType,
        'start_at': startAtIso,
        'end_at': endAtIso,
        'goal_value': goalValue,
        'progress_unit': progressUnit,
        'is_active': isActive,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to create challenge', response),
      );
    }
  }

  static Future<void> updateChallenge(
    int challengeId, {
    String? name,
    String? description,
    String? startAtIso,
    String? endAtIso,
    double? goalValue,
    String? progressUnit,
    bool? isActive,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/admin/challenges/$challengeId',
      body: {
        'name': name,
        'description': description,
        'start_at': startAtIso,
        'end_at': endAtIso,
        'goal_value': goalValue,
        'progress_unit': progressUnit,
        'is_active': isActive,
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update challenge', response),
      );
    }
  }

  static Future<void> deleteChallenge(int challengeId) async {
    final response = await _send('DELETE', '/community/challenges/$challengeId');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to delete challenge', response),
      );
    }
  }

  static Future<List<CommunityBadge>> fetchBadges() async {
    final response = await _send('GET', '/community/badges');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load badges', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityBadge.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<List<CommunityBadge>> fetchEarnedBadges() async {
    final response = await _send('GET', '/community/badges/earned');
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load earned badges', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityBadge.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<List<CommunityReport>> fetchAdminReports({
    int? groupId,
    String? status,
  }) async {
    final response = await _send(
      'GET',
      '/community/admin/reports',
      query: {
        if (groupId != null) 'group_id': groupId,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load moderation reports', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityReport.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<List<CommunityReport>> fetchGroupReports(
    int groupId, {
    String? status,
  }) async {
    final response = await _send(
      'GET',
      '/community/groups/$groupId/reports',
      query: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to load group reports', response),
      );
    }
    return _decodeList(response.body)
        .map((item) => CommunityReport.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<void> reviewReport(
    int reportId, {
    required String status,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/admin/reports/$reportId',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to review report', response),
      );
    }
  }

  static Future<void> setFeedItemVisibility(
    int feedItemId, {
    required bool isHidden,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/feed/$feedItemId/visibility',
      body: {'is_hidden': isHidden},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update feed item visibility', response),
      );
    }
  }

  static Future<void> setCommentStatus(
    int commentId, {
    required String status,
  }) async {
    final response = await _send(
      'PATCH',
      '/community/comments/$commentId/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        _extractError('Failed to update comment status', response),
      );
    }
  }
}
