import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ProgressionClient {
  final int userId;
  final String? name;
  final String? email;
  final String? specialty;
  final String? expertProfileStatus;

  const ProgressionClient({
    required this.userId,
    this.name,
    this.email,
    this.specialty,
    this.expertProfileStatus,
  });

  factory ProgressionClient.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ProgressionClient(
      userId: parseInt(json['user_id']),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      specialty: json['specialty']?.toString(),
      expertProfileStatus: json['expert_profile_status']?.toString(),
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
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }

    return ProgressionReviewItem(
      reviewItemId: parseInt(json['review_item_id']),
      programExerciseId: parseInt(json['program_exercise_id']),
      programDayId: json['program_day_id'] == null ? null : parseInt(json['program_day_id']),
      dayIndex: json['day_index'] == null ? null : parseInt(json['day_index']),
      dayLabel: json['day_label']?.toString(),
      exerciseName: (json['exercise_name'] ?? '').toString(),
      currentSets: parseInt(json['current_sets']),
      currentReps: parseInt(json['current_reps']),
      currentWeightKg: parseDouble(json['current_weight_kg']),
      observedSets: json['observed_sets'] == null ? null : parseInt(json['observed_sets']),
      observedReps: json['observed_reps'] == null ? null : parseInt(json['observed_reps']),
      observedRir: json['observed_rir'] == null ? null : parseInt(json['observed_rir']),
      observedWeightKg: parseDouble(json['observed_weight_kg']),
      observedCompletionDates: parseStringList(json['observed_completion_dates']),
      aiAction: (json['ai_action'] ?? '').toString(),
      aiRecommendedSets: parseInt(json['ai_recommended_sets']),
      aiRecommendedReps: parseInt(json['ai_recommended_reps']),
      aiRecommendedWeightKg: parseDouble(json['ai_recommended_weight_kg']),
      aiReason: json['ai_reason']?.toString(),
      aiConfidence: parseDouble(json['ai_confidence']),
      expertDecision: (json['expert_decision'] ?? '').toString(),
      finalSets: json['final_sets'] == null ? null : parseInt(json['final_sets']),
      finalReps: json['final_reps'] == null ? null : parseInt(json['final_reps']),
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
            .map((e) => ProgressionReviewItem.fromJson(Map<String, dynamic>.from(e)))
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

class ProgressionReviewService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  static Future<Map<String, String>> _authHeaders({bool jsonBody = false}) async {
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

  static Future<List<ProgressionClient>> fetchClients() async {
    final res = await http.get(
      _uri('/coach/progression/clients'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to load progression clients', res.body));
    }
    final decoded = jsonDecode(res.body);
    final raw = decoded is Map ? decoded['clients'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ProgressionClient.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<ProgressionReview>> fetchReviews({
    String? status,
    bool includeApplied = false,
  }) async {
    final query = <String, String>{'include_applied': includeApplied ? 'true' : 'false'};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    final res = await http.get(
      _uri('/coach/progression/reviews', query),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to load progression reviews', res.body));
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
      throw Exception(_extractError('Failed to generate progression review', res.body));
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
      throw Exception(_extractError('Failed to load progression review', res.body));
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
      throw Exception(_extractError('Failed to update progression item', res.body));
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
      throw Exception(_extractError('Failed to apply progression review', res.body));
    }
    return ProgressionReviewDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
