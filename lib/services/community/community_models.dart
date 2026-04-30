import '../../config/base_url.dart';

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => _asMap(item)).toList(growable: false);
}

String? normalizeCommunityUrl(String? rawValue) {
  final raw = rawValue?.trim() ?? '';
  if (raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return raw;
  }
  final base = ApiConfig.baseUrl.trim();
  if (base.isEmpty) return raw;
  try {
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    return baseUri.resolve(raw.startsWith('/') ? raw.substring(1) : raw).toString();
  } catch (_) {
    return raw;
  }
}

class CommunityUserPreview {
  const CommunityUserPreview({
    required this.userId,
    this.displayName,
    this.username,
    this.email,
    this.avatarUrl,
  });

  final int userId;
  final String? displayName;
  final String? username;
  final String? email;
  final String? avatarUrl;

  String get primaryLabel => displayName ?? username ?? email ?? 'User $userId';

  factory CommunityUserPreview.fromJson(Map<String, dynamic> json) {
    return CommunityUserPreview(
      userId: _asInt(json['user_id'] ?? json['id']),
      displayName: _asString(json['display_name'] ?? json['full_name']),
      username: _asString(json['username']),
      email: _asString(json['email']),
      avatarUrl: normalizeCommunityUrl(
        _asString(json['avatar_url'] ?? json['avatar_path']),
      ),
    );
  }
}

class CommunityGroupSummary {
  const CommunityGroupSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isJoined,
    required this.isDiscoverable,
    required this.isReadOnly,
    this.slug,
    this.description,
    this.iconUrl,
    this.visibility,
    this.groupKind,
    this.leaderboardMetric,
    this.currentMemberRole,
    this.joinedAt,
  });

  final int id;
  final String name;
  final int memberCount;
  final bool isJoined;
  final bool isDiscoverable;
  final bool isReadOnly;
  final String? slug;
  final String? description;
  final String? iconUrl;
  final String? visibility;
  final String? groupKind;
  final String? leaderboardMetric;
  final String? currentMemberRole;
  final DateTime? joinedAt;

  bool get isPrivate => visibility == 'private';
  bool get isAdmin => currentMemberRole == 'admin';

  factory CommunityGroupSummary.fromJson(Map<String, dynamic> json) {
    return CommunityGroupSummary(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? 'Community',
      slug: _asString(json['slug']),
      description: _asString(json['description']),
      iconUrl: normalizeCommunityUrl(
        _asString(json['icon_url'] ?? json['icon_path']),
      ),
      visibility: _asString(json['visibility']),
      groupKind: _asString(json['group_kind']),
      memberCount: _asInt(json['member_count']),
      leaderboardMetric: _asString(json['leaderboard_metric']),
      isDiscoverable: _asBool(json['is_discoverable']),
      isReadOnly: _asBool(json['is_read_only']),
      currentMemberRole: _asString(json['current_member_role']),
      isJoined: _asBool(json['is_joined']),
      joinedAt: DateTime.tryParse(_asString(json['joined_at']) ?? ''),
    );
  }
}

class CommunityGroupCreationResult {
  const CommunityGroupCreationResult({
    required this.group,
    this.joinCode,
  });

  final CommunityGroupSummary group;
  final String? joinCode;

  factory CommunityGroupCreationResult.fromJson(Map<String, dynamic> json) {
    final rawCode = _asString(json['join_code']);
    return CommunityGroupCreationResult(
      group: CommunityGroupSummary.fromJson(_asMap(json['group'])),
      joinCode: rawCode == null || rawCode.trim().isEmpty ? null : rawCode.trim(),
    );
  }
}

class CommunityShareSettings {
  const CommunityShareSettings({
    required this.shareTrainingProgress,
    required this.shareTaqaScore,
    required this.shareDailyMovement,
    required this.shareWearableData,
    required this.shareWellness,
    this.updatedAt,
  });

  final bool shareTrainingProgress;
  final bool shareTaqaScore;
  final bool shareDailyMovement;
  final bool shareWearableData;
  final bool shareWellness;
  final DateTime? updatedAt;

  factory CommunityShareSettings.fromJson(Map<String, dynamic> json) {
    return CommunityShareSettings(
      shareTrainingProgress: _asBool(json['share_training_progress']),
      shareTaqaScore: _asBool(json['share_taqa_score']),
      shareDailyMovement: _asBool(json['share_daily_movement']),
      shareWearableData: _asBool(json['share_wearable_data']),
      shareWellness: _asBool(json['share_wellness']),
      updatedAt: DateTime.tryParse(_asString(json['updated_at']) ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'share_training_progress': shareTrainingProgress,
      'share_taqa_score': shareTaqaScore,
      'share_daily_movement': shareDailyMovement,
      'share_wearable_data': shareWearableData,
      'share_wellness': shareWellness,
    };
  }

  CommunityShareSettings copyWith({
    bool? shareTrainingProgress,
    bool? shareTaqaScore,
    bool? shareDailyMovement,
    bool? shareWearableData,
    bool? shareWellness,
  }) {
    return CommunityShareSettings(
      shareTrainingProgress: shareTrainingProgress ?? this.shareTrainingProgress,
      shareTaqaScore: shareTaqaScore ?? this.shareTaqaScore,
      shareDailyMovement: shareDailyMovement ?? this.shareDailyMovement,
      shareWearableData: shareWearableData ?? this.shareWearableData,
      shareWellness: shareWellness ?? this.shareWellness,
      updatedAt: updatedAt,
    );
  }
}

class CommunityPin {
  const CommunityPin({
    required this.pinId,
    required this.pinType,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.sortOrder,
    this.groupId,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final int pinId;
  final int createdBy;
  final int sortOrder;
  final int? groupId;
  final String pinType;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  factory CommunityPin.fromJson(Map<String, dynamic> json) {
    return CommunityPin(
      pinId: _asInt(json['pin_id']),
      groupId: json['group_id'] == null ? null : _asInt(json['group_id']),
      pinType: _asString(json['pin_type']) ?? 'expert_tip',
      title: _asString(json['title']) ?? '',
      body: _asString(json['body']) ?? '',
      createdBy: _asInt(json['created_by']),
      sortOrder: _asInt(json['sort_order']),
      createdAt: DateTime.tryParse(_asString(json['created_at']) ?? ''),
      updatedAt: DateTime.tryParse(_asString(json['updated_at']) ?? ''),
      expiresAt: DateTime.tryParse(_asString(json['expires_at']) ?? ''),
    );
  }
}

class CommunityLeaderboardEntry {
  const CommunityLeaderboardEntry({
    required this.rankPosition,
    required this.userId,
    required this.scoreValue,
    required this.scoreLabel,
    required this.displayName,
    required this.isCurrentUser,
  });

  final int rankPosition;
  final int userId;
  final double scoreValue;
  final String scoreLabel;
  final String displayName;
  final bool isCurrentUser;

  factory CommunityLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CommunityLeaderboardEntry(
      rankPosition: _asInt(json['rank_position']),
      userId: _asInt(json['user_id']),
      scoreValue: _asDouble(json['score_value']),
      scoreLabel: _asString(json['score_label']) ?? '',
      displayName: _asString(json['display_name']) ?? 'Member',
      isCurrentUser: _asBool(json['is_current_user']),
    );
  }
}

class CommunityLeaderboard {
  const CommunityLeaderboard({
    required this.groupId,
    required this.metric,
    required this.items,
    this.snapshotAt,
  });

  final int groupId;
  final String metric;
  final List<CommunityLeaderboardEntry> items;
  final DateTime? snapshotAt;

  factory CommunityLeaderboard.fromJson(Map<String, dynamic> json) {
    return CommunityLeaderboard(
      groupId: _asInt(json['group_id']),
      metric: _asString(json['metric']) ?? 'workout_streak',
      snapshotAt: DateTime.tryParse(_asString(json['snapshot_at']) ?? ''),
      items: _asMapList(json['items'])
          .map(CommunityLeaderboardEntry.fromJson)
          .toList(growable: false),
    );
  }
}

class CommunityGroupDetail {
  const CommunityGroupDetail({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isJoined,
    required this.isDiscoverable,
    required this.isReadOnly,
    required this.adminUserId,
    required this.pinnedItems,
    required this.leaderboardSummary,
    this.slug,
    this.description,
    this.iconUrl,
    this.visibility,
    this.groupKind,
    this.leaderboardMetric,
    this.currentMemberRole,
    this.shareSettings,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int memberCount;
  final bool isJoined;
  final bool isDiscoverable;
  final bool isReadOnly;
  final int adminUserId;
  final List<CommunityPin> pinnedItems;
  final CommunityLeaderboard leaderboardSummary;
  final String? slug;
  final String? description;
  final String? iconUrl;
  final String? visibility;
  final String? groupKind;
  final String? leaderboardMetric;
  final String? currentMemberRole;
  final CommunityShareSettings? shareSettings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPrivate => visibility == 'private';
  bool get isAdmin => currentMemberRole == 'admin';

  factory CommunityGroupDetail.fromJson(Map<String, dynamic> json) {
    final leaderboardMap = _asMap(json['leaderboard_summary']);
    return CommunityGroupDetail(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? 'Community',
      slug: _asString(json['slug']),
      description: _asString(json['description']),
      iconUrl: normalizeCommunityUrl(
        _asString(json['icon_url'] ?? json['icon_path']),
      ),
      visibility: _asString(json['visibility']),
      groupKind: _asString(json['group_kind']),
      adminUserId: _asInt(json['admin_user_id']),
      leaderboardMetric: _asString(json['leaderboard_metric']),
      isDiscoverable: _asBool(json['is_discoverable']),
      isReadOnly: _asBool(json['is_read_only']),
      memberCount: _asInt(json['member_count']),
      currentMemberRole: _asString(json['current_member_role']),
      isJoined: _asBool(json['is_joined']),
      shareSettings: json['share_settings'] == null
          ? null
          : CommunityShareSettings.fromJson(_asMap(json['share_settings'])),
      pinnedItems: _asMapList(json['pinned_items'])
          .map(CommunityPin.fromJson)
          .toList(growable: false),
      leaderboardSummary: CommunityLeaderboard.fromJson({
        'group_id': _asInt(leaderboardMap['group_id'], fallback: _asInt(json['id'])),
        'metric': _asString(leaderboardMap['metric']) ?? _asString(json['leaderboard_metric']) ?? 'workout_streak',
        'snapshot_at': leaderboardMap['snapshot_at'],
        'items': leaderboardMap['items'],
      }),
      createdAt: DateTime.tryParse(_asString(json['created_at']) ?? ''),
      updatedAt: DateTime.tryParse(_asString(json['updated_at']) ?? ''),
    );
  }
}

class CommunityFeedEvent {
  const CommunityFeedEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.payload,
    this.subtitle,
    this.occurredAt,
  });

  final int id;
  final String type;
  final String title;
  final String? subtitle;
  final Map<String, dynamic> payload;
  final DateTime? occurredAt;

  factory CommunityFeedEvent.fromJson(Map<String, dynamic> json) {
    return CommunityFeedEvent(
      id: _asInt(json['id']),
      type: _asString(json['type']) ?? 'activity',
      title: _asString(json['title']) ?? 'Activity',
      subtitle: _asString(json['subtitle']),
      payload: _asMap(json['payload']),
      occurredAt: DateTime.tryParse(_asString(json['occurred_at']) ?? ''),
    );
  }
}

class CommunityFeedItem {
  const CommunityFeedItem({
    required this.feedItemId,
    required this.group,
    required this.event,
    required this.actor,
    required this.likeCount,
    required this.commentCount,
    required this.currentUserLiked,
    required this.canComment,
    this.rankedAt,
  });

  final int feedItemId;
  final CommunityGroupSummary group;
  final CommunityFeedEvent event;
  final CommunityUserPreview actor;
  final int likeCount;
  final int commentCount;
  final bool currentUserLiked;
  final bool canComment;
  final DateTime? rankedAt;

  factory CommunityFeedItem.fromJson(Map<String, dynamic> json) {
    return CommunityFeedItem(
      feedItemId: _asInt(json['feed_item_id']),
      group: CommunityGroupSummary.fromJson(_asMap(json['group'])),
      event: CommunityFeedEvent.fromJson(_asMap(json['event'])),
      actor: CommunityUserPreview.fromJson(_asMap(json['actor'])),
      likeCount: _asInt(json['like_count']),
      commentCount: _asInt(json['comment_count']),
      currentUserLiked: _asBool(json['current_user_liked']),
      canComment: _asBool(json['can_comment']),
      rankedAt: DateTime.tryParse(_asString(json['ranked_at']) ?? ''),
    );
  }

  CommunityFeedItem copyWith({
    int? likeCount,
    int? commentCount,
    bool? currentUserLiked,
  }) {
    return CommunityFeedItem(
      feedItemId: feedItemId,
      group: group,
      event: event,
      actor: actor,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      currentUserLiked: currentUserLiked ?? this.currentUserLiked,
      canComment: canComment,
      rankedAt: rankedAt,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.commentId,
    required this.feedItemId,
    required this.groupId,
    required this.author,
    required this.commentText,
    required this.isOwnComment,
    this.createdAt,
    this.updatedAt,
  });

  final int commentId;
  final int feedItemId;
  final int groupId;
  final CommunityUserPreview author;
  final String commentText;
  final bool isOwnComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      commentId: _asInt(json['comment_id']),
      feedItemId: _asInt(json['feed_item_id']),
      groupId: _asInt(json['group_id']),
      author: CommunityUserPreview.fromJson(_asMap(json['author'])),
      commentText: _asString(json['comment_text']) ?? '',
      isOwnComment: _asBool(json['is_own_comment']),
      createdAt: DateTime.tryParse(_asString(json['created_at']) ?? ''),
      updatedAt: DateTime.tryParse(_asString(json['updated_at']) ?? ''),
    );
  }
}

class CommunityChallenge {
  const CommunityChallenge({
    required this.challengeId,
    required this.name,
    required this.challengeType,
    required this.isActive,
    required this.progressValue,
    required this.progressPercent,
    required this.isCompleted,
    required this.mutedNotifications,
    this.description,
    this.startAt,
    this.endAt,
    this.goalValue,
    this.progressUnit,
    this.completedAt,
  });

  final int challengeId;
  final String name;
  final String challengeType;
  final bool isActive;
  final double progressValue;
  final double progressPercent;
  final bool isCompleted;
  final bool mutedNotifications;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? goalValue;
  final String? progressUnit;
  final DateTime? completedAt;

  bool get isUpcoming => startAt != null && startAt!.isAfter(DateTime.now());

  factory CommunityChallenge.fromJson(Map<String, dynamic> json) {
    return CommunityChallenge(
      challengeId: _asInt(json['challenge_id']),
      name: _asString(json['name']) ?? 'Challenge',
      description: _asString(json['description']),
      challengeType: _asString(json['challenge_type']) ?? 'custom',
      startAt: DateTime.tryParse(_asString(json['start_at']) ?? ''),
      endAt: DateTime.tryParse(_asString(json['end_at']) ?? ''),
      goalValue: json['goal_value'] == null ? null : _asDouble(json['goal_value']),
      progressUnit: _asString(json['progress_unit']),
      isActive: _asBool(json['is_active'], fallback: true),
      progressValue: _asDouble(json['progress_value']),
      progressPercent: _asDouble(json['progress_percent']),
      isCompleted: _asBool(json['is_completed']),
      completedAt: DateTime.tryParse(_asString(json['completed_at']) ?? ''),
      mutedNotifications: _asBool(json['muted_notifications']),
    );
  }

  CommunityChallenge copyWith({
    bool? mutedNotifications,
  }) {
    return CommunityChallenge(
      challengeId: challengeId,
      name: name,
      description: description,
      challengeType: challengeType,
      startAt: startAt,
      endAt: endAt,
      goalValue: goalValue,
      progressUnit: progressUnit,
      isActive: isActive,
      progressValue: progressValue,
      progressPercent: progressPercent,
      isCompleted: isCompleted,
      completedAt: completedAt,
      mutedNotifications: mutedNotifications ?? this.mutedNotifications,
    );
  }
}

class CommunityBadge {
  const CommunityBadge({
    required this.badgeKey,
    required this.name,
    required this.category,
    required this.description,
    required this.isEarned,
    this.badgeId,
    this.userBadgeId,
    this.triggerType,
    this.awardedAt,
    this.awardMetadata,
  });

  final int? badgeId;
  final int? userBadgeId;
  final String badgeKey;
  final String name;
  final String category;
  final String description;
  final String? triggerType;
  final bool isEarned;
  final DateTime? awardedAt;
  final Map<String, dynamic>? awardMetadata;

  factory CommunityBadge.fromJson(Map<String, dynamic> json) {
    return CommunityBadge(
      badgeId: json['badge_id'] == null ? null : _asInt(json['badge_id']),
      userBadgeId: json['user_badge_id'] == null ? null : _asInt(json['user_badge_id']),
      badgeKey: _asString(json['badge_key']) ?? '',
      name: _asString(json['name']) ?? 'Badge',
      category: _asString(json['category']) ?? 'general',
      description: _asString(json['description']) ?? '',
      triggerType: _asString(json['trigger_type']),
      isEarned: _asBool(json['is_earned'] ?? (json['awarded_at'] != null)),
      awardedAt: DateTime.tryParse(_asString(json['awarded_at']) ?? ''),
      awardMetadata: json['award_metadata'] == null ? null : _asMap(json['award_metadata']),
    );
  }
}

class CommunityReport {
  const CommunityReport({
    required this.reportId,
    required this.reporterUserId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    this.details,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
  });

  final int reportId;
  final int reporterUserId;
  final int targetId;
  final int? reviewedBy;
  final String targetType;
  final String reason;
  final String status;
  final String? details;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    return CommunityReport(
      reportId: _asInt(json['report_id']),
      reporterUserId: _asInt(json['reporter_user_id']),
      targetType: _asString(json['target_type']) ?? 'feed_item',
      targetId: _asInt(json['target_id']),
      reason: _asString(json['reason']) ?? 'other',
      details: _asString(json['details']),
      status: _asString(json['status']) ?? 'open',
      reviewedBy: json['reviewed_by'] == null ? null : _asInt(json['reviewed_by']),
      reviewedAt: DateTime.tryParse(_asString(json['reviewed_at']) ?? ''),
      createdAt: DateTime.tryParse(_asString(json['created_at']) ?? ''),
    );
  }
}

class CommunityMembership {
  const CommunityMembership({
    required this.membershipId,
    required this.userId,
    required this.role,
    required this.status,
    required this.mutedNotifications,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.joinedAt,
    this.leftAt,
  });

  final int membershipId;
  final int userId;
  final String role;
  final String status;
  final bool mutedNotifications;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  factory CommunityMembership.fromJson(Map<String, dynamic> json) {
    return CommunityMembership(
      membershipId: _asInt(json['membership_id']),
      userId: _asInt(json['user_id']),
      role: _asString(json['role']) ?? 'member',
      status: _asString(json['status']) ?? 'active',
      mutedNotifications: _asBool(json['muted_notifications']),
      displayName: _asString(json['display_name']) ?? 'Member',
      username: _asString(json['username']),
      avatarUrl: normalizeCommunityUrl(_asString(json['avatar_url'])),
      joinedAt: DateTime.tryParse(_asString(json['joined_at']) ?? ''),
      leftAt: DateTime.tryParse(_asString(json['left_at']) ?? ''),
    );
  }
}

class CommunityBootstrap {
  const CommunityBootstrap({
    required this.currentUser,
    required this.joinedGroups,
    required this.activeChallenges,
    required this.unreadModerationReportNoticesCount,
    required this.groupKinds,
    required this.leaderboardMetrics,
  });

  final CommunityUserPreview currentUser;
  final List<CommunityGroupSummary> joinedGroups;
  final List<CommunityChallenge> activeChallenges;
  final int unreadModerationReportNoticesCount;
  final List<String> groupKinds;
  final List<String> leaderboardMetrics;

  bool get hasAdminAccess => joinedGroups.any((group) => group.isAdmin);

  factory CommunityBootstrap.fromJson(Map<String, dynamic> json) {
    final filters = _asMap(json['feed_filters_metadata']);
    final challengeSummary = _asMap(json['active_challenges_summary']);
    final kinds = (filters['group_kinds'] as List?)
            ?.map((item) => _asString(item))
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final metrics = (filters['leaderboard_metrics'] as List?)
            ?.map((item) => _asString(item))
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    return CommunityBootstrap(
      currentUser: CommunityUserPreview.fromJson(_asMap(json['current_user'])),
      joinedGroups: _asMapList(json['joined_groups'])
          .map(CommunityGroupSummary.fromJson)
          .toList(growable: false),
      activeChallenges: _asMapList(challengeSummary['items'])
          .map(CommunityChallenge.fromJson)
          .toList(growable: false),
      unreadModerationReportNoticesCount: _asInt(
        json['unread_moderation_report_notices_count'],
      ),
      groupKinds: kinds,
      leaderboardMetrics: metrics,
    );
  }
}

class CommunityPagedResult<T> {
  const CommunityPagedResult({
    required this.items,
    this.nextCursor,
  });

  final List<T> items;
  final int? nextCursor;
}
