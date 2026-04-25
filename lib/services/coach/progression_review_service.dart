import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'form_check_service.dart';

class ProgressionClient {
  final int userId;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String? specialty;
  final String? expertProfileStatus;
  final String? activityStatus;
  final int? inactiveDays;
  final String? lastActionDate;
  final String? lastTrainingDate;
  final String? lastCardioDate;
  final String? lastHabitDate;
  final int sharedFormCheckCount;
  final bool hasFormCheckToReview;

  const ProgressionClient({
    required this.userId,
    this.name,
    this.email,
    this.avatarUrl,
    this.specialty,
    this.expertProfileStatus,
    this.activityStatus,
    this.inactiveDays,
    this.lastActionDate,
    this.lastTrainingDate,
    this.lastCardioDate,
    this.lastHabitDate,
    this.sharedFormCheckCount = 0,
    this.hasFormCheckToReview = false,
  });

  ProgressionClient copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? specialty,
    String? expertProfileStatus,
    String? activityStatus,
    int? inactiveDays,
    String? lastActionDate,
    String? lastTrainingDate,
    String? lastCardioDate,
    String? lastHabitDate,
    int? sharedFormCheckCount,
    bool? hasFormCheckToReview,
  }) {
    return ProgressionClient(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      specialty: specialty ?? this.specialty,
      expertProfileStatus: expertProfileStatus ?? this.expertProfileStatus,
      activityStatus: activityStatus ?? this.activityStatus,
      inactiveDays: inactiveDays ?? this.inactiveDays,
      lastActionDate: lastActionDate ?? this.lastActionDate,
      lastTrainingDate: lastTrainingDate ?? this.lastTrainingDate,
      lastCardioDate: lastCardioDate ?? this.lastCardioDate,
      lastHabitDate: lastHabitDate ?? this.lastHabitDate,
      sharedFormCheckCount: sharedFormCheckCount ?? this.sharedFormCheckCount,
      hasFormCheckToReview: hasFormCheckToReview ?? this.hasFormCheckToReview,
    );
  }

  factory ProgressionClient.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    String? parseString(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'none') return null;
      return raw;
    }

    String? pickFirstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        final parsed = parseString(value);
        if (parsed != null) return parsed;
      }
      return null;
    }

    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      final raw = value?.toString().trim().toLowerCase() ?? '';
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    return ProgressionClient(
      userId: parseInt(json['user_id']),
      name: parseString(json['name']),
      email: parseString(json['email']),
      avatarUrl: pickFirstNonEmpty([
        json['avatar_url'],
        json['avatarUrl'],
        json['profile_avatar_url'],
        json['profile_image_url'],
      ]),
      specialty: parseString(json['specialty']),
      expertProfileStatus: parseString(json['expert_profile_status']),
      activityStatus: parseString(json['activity_status']),
      inactiveDays: parseIntOrNull(json['inactive_days']),
      lastActionDate: parseString(json['last_action_date']),
      lastTrainingDate: parseString(json['last_training_date']),
      lastCardioDate: parseString(json['last_cardio_date']),
      lastHabitDate: parseString(json['last_habit_date']),
      sharedFormCheckCount: parseInt(json['shared_form_check_count']),
      hasFormCheckToReview: parseBool(json['has_form_check_to_review']),
    );
  }
}

class ProgressionReview {
  final int reviewId;
  final int userId;
  final int expertUserId;
  final int programId;
  final String? weekStart;
  final String? weekEnd;
  final String? triggerSource;
  final String status;
  final String? geminiModel;
  final String? promptVersion;
  final String? aiSummary;
  final String? reviewedAt;
  final String? appliedAt;
  final String? lastError;
  final String? clientName;
  final int itemCount;

  const ProgressionReview({
    required this.reviewId,
    required this.userId,
    required this.expertUserId,
    required this.programId,
    required this.status,
    required this.itemCount,
    this.weekStart,
    this.weekEnd,
    this.triggerSource,
    this.geminiModel,
    this.promptVersion,
    this.aiSummary,
    this.reviewedAt,
    this.appliedAt,
    this.lastError,
    this.clientName,
  });

  bool get isApplied => status == 'applied';
  bool get isPendingExpert => status == 'pending_expert';
  bool get isReviewed => status == 'reviewed';

  factory ProgressionReview.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ProgressionReview(
      reviewId: parseInt(json['review_id']),
      userId: parseInt(json['user_id']),
      expertUserId: parseInt(json['expert_user_id']),
      programId: parseInt(json['program_id']),
      status: (json['status'] ?? '').toString(),
      itemCount: parseInt(json['item_count']),
      weekStart: json['week_start']?.toString(),
      weekEnd: json['week_end']?.toString(),
      triggerSource: json['trigger_source']?.toString(),
      geminiModel: json['gemini_model']?.toString(),
      promptVersion: json['prompt_version']?.toString(),
      aiSummary: json['ai_summary']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      appliedAt: json['applied_at']?.toString(),
      lastError: json['last_error']?.toString(),
      clientName: json['client_name']?.toString(),
    );
  }
}

class ProgressionReviewItem {
  final int reviewItemId;
  final int programExerciseId;
  final int? programDayId;
  final int? dayIndex;
  final String? dayLabel;
  final String exerciseName;
  final int currentSets;
  final int currentReps;
  final double? currentWeightKg;
  final int? observedSets;
  final int? observedReps;
  final int? observedRir;
  final double? observedWeightKg;
  final List<String> observedCompletionDates;
  final String aiAction;
  final int aiRecommendedSets;
  final int aiRecommendedReps;
  final double? aiRecommendedWeightKg;
  final String? aiReason;
  final double? aiConfidence;
  final String expertDecision;
  final int? finalSets;
  final int? finalReps;
  final double? finalWeightKg;
  final String? expertNote;

  const ProgressionReviewItem({
    required this.reviewItemId,
    required this.programExerciseId,
    required this.exerciseName,
    required this.currentSets,
    required this.currentReps,
    required this.aiAction,
    required this.aiRecommendedSets,
    required this.aiRecommendedReps,
    required this.expertDecision,
    this.programDayId,
    this.dayIndex,
    this.dayLabel,
    this.currentWeightKg,
    this.observedSets,
    this.observedReps,
    this.observedRir,
    this.observedWeightKg,
    required this.observedCompletionDates,
    this.aiRecommendedWeightKg,
    this.aiReason,
    this.aiConfidence,
    this.finalSets,
    this.finalReps,
    this.finalWeightKg,
    this.expertNote,
  });

  bool get isApprovedLike =>
      expertDecision == 'approved' || expertDecision == 'edited';

  factory ProgressionReviewItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return ProgressionReviewItem(
      reviewItemId: parseInt(json['review_item_id']),
      programExerciseId: parseInt(json['program_exercise_id']),
      programDayId: json['program_day_id'] == null
          ? null
          : parseInt(json['program_day_id']),
      dayIndex: json['day_index'] == null ? null : parseInt(json['day_index']),
      dayLabel: json['day_label']?.toString(),
      exerciseName: (json['exercise_name'] ?? '').toString(),
      currentSets: parseInt(json['current_sets']),
      currentReps: parseInt(json['current_reps']),
      currentWeightKg: parseDouble(json['current_weight_kg']),
      observedSets: json['observed_sets'] == null
          ? null
          : parseInt(json['observed_sets']),
      observedReps: json['observed_reps'] == null
          ? null
          : parseInt(json['observed_reps']),
      observedRir: json['observed_rir'] == null
          ? null
          : parseInt(json['observed_rir']),
      observedWeightKg: parseDouble(json['observed_weight_kg']),
      observedCompletionDates: parseStringList(
        json['observed_completion_dates'],
      ),
      aiAction: (json['ai_action'] ?? '').toString(),
      aiRecommendedSets: parseInt(json['ai_recommended_sets']),
      aiRecommendedReps: parseInt(json['ai_recommended_reps']),
      aiRecommendedWeightKg: parseDouble(json['ai_recommended_weight_kg']),
      aiReason: json['ai_reason']?.toString(),
      aiConfidence: parseDouble(json['ai_confidence']),
      expertDecision: (json['expert_decision'] ?? '').toString(),
      finalSets: json['final_sets'] == null
          ? null
          : parseInt(json['final_sets']),
      finalReps: json['final_reps'] == null
          ? null
          : parseInt(json['final_reps']),
      finalWeightKg: parseDouble(json['final_weight_kg']),
      expertNote: json['expert_note']?.toString(),
    );
  }
}

class ProgressionReviewDetail extends ProgressionReview {
  final List<ProgressionReviewItem> items;

  const ProgressionReviewDetail({
    required super.reviewId,
    required super.userId,
    required super.expertUserId,
    required super.programId,
    required super.status,
    required super.itemCount,
    required this.items,
    super.weekStart,
    super.weekEnd,
    super.triggerSource,
    super.geminiModel,
    super.promptVersion,
    super.aiSummary,
    super.reviewedAt,
    super.appliedAt,
    super.lastError,
    super.clientName,
  });

  factory ProgressionReviewDetail.fromJson(Map<String, dynamic> json) {
    final base = ProgressionReview.fromJson(json);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (e) => ProgressionReviewItem.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <ProgressionReviewItem>[];
    return ProgressionReviewDetail(
      reviewId: base.reviewId,
      userId: base.userId,
      expertUserId: base.expertUserId,
      programId: base.programId,
      status: base.status,
      itemCount: items.length,
      items: items,
      weekStart: base.weekStart,
      weekEnd: base.weekEnd,
      triggerSource: base.triggerSource,
      geminiModel: base.geminiModel,
      promptVersion: base.promptVersion,
      aiSummary: base.aiSummary,
      reviewedAt: base.reviewedAt,
      appliedAt: base.appliedAt,
      lastError: base.lastError,
      clientName: base.clientName,
    );
  }
}

class CoachDietComment {
  final int commentId;
  final int clientUserId;
  final int coachUserId;
  final String mealDate;
  final int? mealId;
  final int? mealIndex;
  final String? mealTitle;
  final String commentText;
  final bool isPinned;
  final DateTime? pinnedAt;
  final DateTime? clientSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoachDietComment({
    required this.commentId,
    required this.clientUserId,
    required this.coachUserId,
    required this.mealDate,
    this.mealId,
    this.mealIndex,
    this.mealTitle,
    required this.commentText,
    required this.isPinned,
    this.pinnedAt,
    this.clientSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory CoachDietComment.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return CoachDietComment(
      commentId: parseInt(json['comment_id']),
      clientUserId: parseInt(json['client_user_id']),
      coachUserId: parseInt(json['coach_user_id']),
      mealDate: (json['meal_date'] ?? '').toString(),
      mealId: json['meal_id'] == null ? null : parseInt(json['meal_id']),
      mealIndex: json['meal_index'] == null
          ? null
          : parseInt(json['meal_index']),
      mealTitle: json['meal_title']?.toString(),
      commentText: (json['comment_text'] ?? '').toString(),
      isPinned: json['is_pinned'] == true,
      pinnedAt: parseDate(json['pinned_at']),
      clientSeenAt: parseDate(json['client_seen_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class ProgressionReviewService {
  static final Map<int, String?> _avatarUrlCache = <int, String?>{};

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  static Future<Map<String, String>> _authHeaders({
    bool jsonBody = false,
  }) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (!jsonBody) return headers;
    return {'Content-Type': 'application/json', ...headers};
  }

  static Future<void> _handleAuth(http.Response response) async {
    await AccountStorage.handleAuthStatus(
      response.statusCode,
      responseBody: response.body,
    );
  }

  static String _extractError(String fallback, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String? _normalizeAvatarUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'null' || lower == 'none') return null;
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchAvatarUrlForUser(
    int userId, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _avatarUrlCache.containsKey(userId)) {
      return _avatarUrlCache[userId];
    }
    try {
      final res = await http.get(
        _uri('/profile/$userId'),
        headers: headers ?? await _authHeaders(),
      );
      await _handleAuth(res);
      if (res.statusCode != 200) {
        _avatarUrlCache[userId] = null;
        return null;
      }
      final decoded = jsonDecode(res.body);
      final avatar = decoded is Map
          ? _normalizeAvatarUrl(decoded['avatar_url']) ??
                _normalizeAvatarUrl(decoded['avatarUrl']) ??
                _normalizeAvatarUrl(decoded['profile_avatar_url']) ??
                _normalizeAvatarUrl(decoded['profile_image_url'])
          : null;
      _avatarUrlCache[userId] = avatar;
      return avatar;
    } catch (_) {
      _avatarUrlCache[userId] = null;
      return null;
    }
  }

  static bool _needsAvatarRefresh(String? avatarUrl) {
    final normalized = _normalizeAvatarUrl(avatarUrl);
    if (normalized == null) return true;
    final lower = normalized.toLowerCase();
    if (lower.contains('/null')) return true;
    if (lower.startsWith('gs://')) return true;
    if (lower.contains('storage.googleapis.com') &&
        !lower.contains('x-goog-signature=')) {
      return true;
    }
    if (lower.contains('/avatars/') && !lower.contains('/static/avatars/')) {
      return true;
    }
    return false;
  }

  static Future<List<ProgressionClient>> fetchClients() async {
    final res = await http.get(
      _uri('/coach/progression/clients'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load progression clients', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['clients'] : null;
    if (raw is! List) return const [];
    final clients = raw
        .whereType<Map>()
        .map((e) => ProgressionClient.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final normalizedClients = clients.map((client) {
      final avatar = _normalizeAvatarUrl(client.avatarUrl);
      if (avatar == null) return client.copyWith(avatarUrl: null);
      return client.copyWith(avatarUrl: avatar);
    }).toList();

    for (final client in normalizedClients) {
      final avatar = _normalizeAvatarUrl(client.avatarUrl);
      if (avatar != null && !_needsAvatarRefresh(avatar)) {
        _avatarUrlCache[client.userId] = avatar;
      }
    }

    final clientsNeedingAvatarRefresh = normalizedClients
        .where((client) => _needsAvatarRefresh(client.avatarUrl))
        .toList();
    List<ProgressionClient> sortByReviewPriority(
      List<ProgressionClient> input,
    ) {
      input.sort((a, b) {
        if (a.hasFormCheckToReview != b.hasFormCheckToReview) {
          return b.hasFormCheckToReview ? 1 : -1;
        }
        if (a.sharedFormCheckCount != b.sharedFormCheckCount) {
          return b.sharedFormCheckCount.compareTo(a.sharedFormCheckCount);
        }
        final aName = (a.name ?? '').toLowerCase();
        final bName = (b.name ?? '').toLowerCase();
        return aName.compareTo(bName);
      });
      return input;
    }

    if (clientsNeedingAvatarRefresh.isEmpty) {
      return sortByReviewPriority(normalizedClients);
    }

    final headers = await _authHeaders();
    final fetchedAvatars = <int, String?>{};
    await Future.wait(
      clientsNeedingAvatarRefresh.map((client) async {
        fetchedAvatars[client.userId] = await _fetchAvatarUrlForUser(
          client.userId,
          headers: headers,
          forceRefresh: true,
        );
      }),
    );

    return sortByReviewPriority(
      normalizedClients.map((client) {
        final avatar =
            _normalizeAvatarUrl(fetchedAvatars[client.userId]) ??
            _normalizeAvatarUrl(client.avatarUrl);
        if (avatar == null) return client;
        return client.copyWith(avatarUrl: avatar);
      }).toList(),
    );
  }

  static Future<List<FormCheckSubmission>> fetchClientSharedFormChecks(
    int clientUserId,
  ) async {
    final res = await http.get(
      _uri('/coach/progression/clients/$clientUserId/form-checks'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load shared Form Check videos', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['items'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => FormCheckSubmission.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchClientDietLog({
    required int clientUserId,
    DateTime? mealDate,
  }) async {
    final query = <String, String>{};
    if (mealDate != null) {
      query['meal_date'] = _dateOnly(mealDate);
    }
    final res = await http.get(
      _uri('/diet/meals/$clientUserId', {...query, 'auto_open': 'false'}),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load client diet log', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final log = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final meals = log['meals'];
    var loggedItemsCount = 0;
    if (meals is List) {
      for (final meal in meals) {
        if (meal is! Map) continue;
        final items = meal['items'];
        if (items is List) {
          loggedItemsCount += items.length;
        }
      }
    }
    final mealDateToken = query['meal_date'] ?? _dateOnly(DateTime.now());
    return {
      'coach_user_id': null,
      'client_user_id': clientUserId,
      'meal_date': mealDateToken,
      'logged_dates': const <String>[],
      'has_logged_items': loggedItemsCount > 0,
      'logged_items_count': loggedItemsCount,
      'diet_log': log,
    };
  }

  static Future<List<CoachDietComment>> fetchClientDietComments({
    required int clientUserId,
    int limit = 80,
  }) async {
    final res = await http.get(
      _uri('/coach/progression/clients/$clientUserId/diet-comments', {
        'limit': '$limit',
      }),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode == 403) {
      return const [];
    }
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load client diet comments', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['items'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => CoachDietComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<CoachDietComment> addClientDietComment({
    required int clientUserId,
    required DateTime mealDate,
    required int mealId,
    required String commentText,
  }) async {
    final res = await http.post(
      _uri('/coach/progression/clients/$clientUserId/diet-comments'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({
        'meal_date': _dateOnly(mealDate),
        'meal_id': mealId,
        'comment_text': commentText.trim(),
      }),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to save diet comment', res.body));
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['item'] : null;
    if (raw is! Map) {
      throw Exception('Invalid response while saving diet comment');
    }
    return CoachDietComment.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<CoachDietComment> setClientDietCommentPinned({
    required int clientUserId,
    required int commentId,
    required bool isPinned,
  }) async {
    final res = await http.patch(
      _uri(
        '/coach/progression/clients/$clientUserId/diet-comments/$commentId/pin',
      ),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'is_pinned': isPinned}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update diet comment pin', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['item'] : null;
    if (raw is! Map) {
      throw Exception('Invalid response while updating diet comment pin');
    }
    return CoachDietComment.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<void> deleteClientDietComment({
    required int clientUserId,
    required int commentId,
  }) async {
    final res = await http.delete(
      _uri('/coach/progression/clients/$clientUserId/diet-comments/$commentId'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to delete diet comment', res.body));
    }
  }

  static Future<FormCheckSubmission> submitFormCheckReview({
    required int submissionId,
    required String reviewText,
    bool? pin,
  }) async {
    final payload = <String, dynamic>{'review_text': reviewText.trim()};
    if (pin != null) {
      payload['pin'] = pin;
    }
    final res = await http.patch(
      _uri('/coach/progression/form-checks/$submissionId/review'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode(payload),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to submit Form Check review', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckSubmission> submitFormCheckVoiceNote({
    required int submissionId,
    required String audioFilePath,
    String? reviewText,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/coach/progression/form-checks/$submissionId/voice-note'),
    );
    request.headers.addAll(await _authHeaders());
    final normalizedReviewText = (reviewText ?? '').trim();
    if (normalizedReviewText.isNotEmpty) {
      request.fields['review_text'] = normalizedReviewText;
    }
    request.files.add(
      await http.MultipartFile.fromPath('voice_note', audioFilePath),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to submit Form Check voice note', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckSubmission> setFormCheckReviewPinned({
    required int submissionId,
    required bool isPinned,
  }) async {
    final res = await http.patch(
      _uri('/coach/progression/form-checks/$submissionId/pin'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'is_pinned': isPinned}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update Form Check pin', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckSubmission> setFormCheckReplyPinned({
    required int submissionId,
    required int replyId,
    required bool isPinned,
  }) async {
    final res = await http.patch(
      _uri('/coach/progression/form-checks/$submissionId/replies/$replyId/pin'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'is_pinned': isPinned}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update Form Check reply pin', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<List<ProgressionReview>> fetchReviews({
    String? status,
    bool includeApplied = false,
  }) async {
    final query = <String, String>{
      'include_applied': includeApplied ? 'true' : 'false',
    };
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final res = await http.get(
      _uri('/coach/progression/reviews', query),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load progression reviews', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['reviews'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ProgressionReview.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Map<String, dynamic>> generateReview(
    int clientUserId, {
    bool force = false,
  }) async {
    final res = await http.post(
      _uri('/coach/progression/reviews/generate/$clientUserId', {
        'force': force ? 'true' : 'false',
      }),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to generate progression review', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  static Future<ProgressionReviewDetail> fetchReviewDetail(int reviewId) async {
    final res = await http.get(
      _uri('/coach/progression/reviews/$reviewId'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load progression review', res.body),
      );
    }
    return ProgressionReviewDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<ProgressionReviewDetail> updateReviewItem({
    required int reviewItemId,
    required String expertDecision,
    int? finalSets,
    int? finalReps,
    double? finalWeightKg,
    String? expertNote,
  }) async {
    final res = await http.patch(
      _uri('/coach/progression/items/$reviewItemId'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({
        'expert_decision': expertDecision,
        'final_sets': finalSets,
        'final_reps': finalReps,
        'final_weight_kg': finalWeightKg,
        'expert_note': expertNote,
      }),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update progression item', res.body),
      );
    }
    return ProgressionReviewDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<ProgressionReviewDetail> applyReview(int reviewId) async {
    final res = await http.post(
      _uri('/coach/progression/reviews/$reviewId/apply'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to apply progression review', res.body),
      );
    }
    return ProgressionReviewDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<Map<String, dynamic>> fetchClientAnalytics(
    int clientUserId, {
    int weekOffset = 0,
  }) async {
    final query = <String, String>{};
    if (weekOffset > 0) {
      query['week_offset'] = '$weekOffset';
    }
    final res = await http.get(
      _uri('/coach/progression/clients/$clientUserId/analytics', query),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load client analytics', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static Future<List<Map<String, dynamic>>> fetchClientTrainingHistory({
    required int clientUserId,
    int limitDays = 180,
  }) async {
    final res = await http.get(
      _uri('/coach/progression/clients/$clientUserId/training-history', {
        'limit_days': '$limitDays',
      }),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load client training history', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map
        ? (decoded['items'] ?? decoded['history'] ?? decoded['entries'])
        : decoded;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
