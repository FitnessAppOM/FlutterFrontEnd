import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class FormCheckUsage {
  final int usedThisWeek;
  final int remainingThisWeek;
  final int weeklyLimit;
  final DateTime? weekStart;
  final DateTime? weekEnd;

  const FormCheckUsage({
    required this.usedThisWeek,
    required this.remainingThisWeek,
    required this.weeklyLimit,
    this.weekStart,
    this.weekEnd,
  });

  factory FormCheckUsage.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return FormCheckUsage(
      usedThisWeek: parseInt(json['used_this_week']),
      remainingThisWeek: parseInt(json['remaining_this_week']),
      weeklyLimit: parseInt(json['weekly_limit']),
      weekStart: parseDate(json['week_start']),
      weekEnd: parseDate(json['week_end']),
    );
  }
}

class FormCheckResultData {
  final String? poseStatus;
  final Map<String, dynamic> poseSummary;
  final bool overlayGenerated;
  final String? overlayUrl;
  final String? geminiStatus;
  final String? feedbackSummary;
  final List<String> feedbackBullets;
  final List<String> detectedIssues;
  final String? modelName;
  final String? promptVersion;
  final Map<String, dynamic> resultPayload;

  const FormCheckResultData({
    this.poseStatus,
    required this.poseSummary,
    required this.overlayGenerated,
    this.overlayUrl,
    this.geminiStatus,
    this.feedbackSummary,
    required this.feedbackBullets,
    required this.detectedIssues,
    this.modelName,
    this.promptVersion,
    required this.resultPayload,
  });

  factory FormCheckResultData.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    return FormCheckResultData(
      poseStatus: json['pose_status']?.toString(),
      poseSummary: parseMap(json['pose_summary']),
      overlayGenerated: json['overlay_generated'] == true,
      overlayUrl: json['overlay_url']?.toString(),
      geminiStatus: json['gemini_status']?.toString(),
      feedbackSummary: json['feedback_summary']?.toString(),
      feedbackBullets: parseStringList(json['feedback_bullets']),
      detectedIssues: parseStringList(json['detected_issues']),
      modelName: json['model_name']?.toString(),
      promptVersion: json['prompt_version']?.toString(),
      resultPayload: parseMap(json['result_payload']),
    );
  }
}

class FormCheckCoachReview {
  final int submissionId;
  final int coachUserId;
  final String reviewStatus;
  final String? reviewText;
  final bool isPinned;
  final DateTime? reviewedAt;
  final DateTime? pinnedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? clientSeenAt;
  final String? voiceNoteUrl;

  const FormCheckCoachReview({
    required this.submissionId,
    required this.coachUserId,
    required this.reviewStatus,
    this.reviewText,
    required this.isPinned,
    this.reviewedAt,
    this.pinnedAt,
    this.createdAt,
    this.updatedAt,
    this.clientSeenAt,
    this.voiceNoteUrl,
  });

  factory FormCheckCoachReview.fromJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    String? parseString(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return raw;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = value?.toString().trim().toLowerCase() ?? '';
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    return FormCheckCoachReview(
      submissionId: parseInt(
        pick(['submission_id', 'submissionId', 'form_check_submission_id']),
      ),
      coachUserId: parseInt(pick(['coach_user_id', 'coachUserId'])),
      reviewStatus: (pick(['review_status', 'reviewStatus', 'status']) ?? '')
          .toString(),
      reviewText: parseString(
        pick(['review_text', 'reviewText', 'text', 'message']),
      ),
      isPinned: parseBool(pick(['is_pinned', 'isPinned'])),
      reviewedAt: parseDate(pick(['reviewed_at', 'reviewedAt'])),
      pinnedAt: parseDate(pick(['pinned_at', 'pinnedAt'])),
      createdAt: parseDate(pick(['created_at', 'createdAt'])),
      updatedAt: parseDate(pick(['updated_at', 'updatedAt'])),
      clientSeenAt: parseDate(pick(['client_seen_at', 'clientSeenAt'])),
      voiceNoteUrl: parseString(
        pick([
          'voice_note_url',
          'voiceNoteUrl',
          'review_voice_note_url',
          'reviewVoiceNoteUrl',
          'voice_note',
          'voiceNote',
        ]),
      ),
    );
  }
}

class FormCheckCoachReply {
  final int replyId;
  final int submissionId;
  final int coachUserId;
  final String replyText;
  final String? voiceNoteUrl;
  final bool isPinned;
  final DateTime? pinnedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? clientSeenAt;

  const FormCheckCoachReply({
    required this.replyId,
    required this.submissionId,
    required this.coachUserId,
    required this.replyText,
    this.voiceNoteUrl,
    required this.isPinned,
    this.pinnedAt,
    this.createdAt,
    this.updatedAt,
    this.clientSeenAt,
  });

  factory FormCheckCoachReply.fromJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = value?.toString().trim().toLowerCase() ?? '';
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    String? parseString(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return raw;
    }

    return FormCheckCoachReply(
      replyId: parseInt(pick(['reply_id', 'replyId', 'id'])),
      submissionId: parseInt(
        pick(['submission_id', 'submissionId', 'form_check_submission_id']),
      ),
      coachUserId: parseInt(pick(['coach_user_id', 'coachUserId'])),
      replyText: (pick(['reply_text', 'replyText', 'text', 'message']) ?? '')
          .toString(),
      voiceNoteUrl: parseString(
        pick([
          'voice_note_url',
          'voiceNoteUrl',
          'reply_voice_note_url',
          'replyVoiceNoteUrl',
          'voice_note',
          'voiceNote',
        ]),
      ),
      isPinned: parseBool(pick(['is_pinned', 'isPinned'])),
      pinnedAt: parseDate(pick(['pinned_at', 'pinnedAt'])),
      createdAt: parseDate(pick(['created_at', 'createdAt'])),
      updatedAt: parseDate(pick(['updated_at', 'updatedAt'])),
      clientSeenAt: parseDate(pick(['client_seen_at', 'clientSeenAt'])),
    );
  }
}

class FormCheckSubmission {
  final int submissionId;
  final int userId;
  final int? exerciseId;
  final String exerciseName;
  final String? originalFilename;
  final String? originalVideoUrl;
  final String? overlayVideoUrl;
  final String mimeType;
  final int fileSizeBytes;
  final double durationSeconds;
  final String status;
  final bool consentAccepted;
  final bool savedToLibrary;
  final bool sharedWithCoach;
  final int? sharedCoachUserId;
  final DateTime? sharedAt;
  final String? failureReason;
  final DateTime? deleteAfter;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final FormCheckResultData result;
  final FormCheckCoachReview? coachReview;
  final List<FormCheckCoachReply> coachReviewReplies;

  const FormCheckSubmission({
    required this.submissionId,
    required this.userId,
    this.exerciseId,
    required this.exerciseName,
    this.originalFilename,
    this.originalVideoUrl,
    this.overlayVideoUrl,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.status,
    required this.consentAccepted,
    required this.savedToLibrary,
    required this.sharedWithCoach,
    this.sharedCoachUserId,
    this.sharedAt,
    this.failureReason,
    this.deleteAfter,
    this.createdAt,
    this.updatedAt,
    required this.result,
    this.coachReview,
    required this.coachReviewReplies,
  });

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory FormCheckSubmission.fromJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final raw = value?.toString().trim().toLowerCase() ?? '';
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    String? parseString(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return raw;
    }

    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final resultJson =
        pick(['result', 'form_check_result', 'formCheckResult']) ??
        pick(['result_payload', 'resultPayload']);
    final result = resultJson is Map<String, dynamic>
        ? resultJson
        : (resultJson is Map
              ? Map<String, dynamic>.from(resultJson)
              : <String, dynamic>{});
    final topSubmissionId = parseInt(
      pick(['submission_id', 'submissionId', 'id']),
    );
    final coachReviewJson = pick(['coach_review', 'coachReview']);
    Map<String, dynamic>? coachReview = parseMap(coachReviewJson);
    if (coachReview == null) {
      final flattened = <String, dynamic>{
        'submission_id': topSubmissionId,
        'coach_user_id': pick([
          'coach_review_coach_user_id',
          'coachReviewCoachUserId',
          'review_coach_user_id',
          'reviewCoachUserId',
          'review_user_id',
          'reviewUserId',
        ]),
        'review_status': pick([
          'coach_review_status',
          'coachReviewStatus',
          'review_status',
          'reviewStatus',
        ]),
        'review_text': pick([
          'coach_review_text',
          'coachReviewText',
          'review_text',
          'reviewText',
        ]),
        'is_pinned': pick([
          'coach_review_is_pinned',
          'coachReviewIsPinned',
          'review_is_pinned',
          'reviewIsPinned',
          'is_review_pinned',
          'isReviewPinned',
        ]),
        'reviewed_at': pick([
          'coach_review_reviewed_at',
          'coachReviewReviewedAt',
          'reviewed_at',
          'reviewedAt',
        ]),
        'pinned_at': pick([
          'coach_review_pinned_at',
          'coachReviewPinnedAt',
          'review_pinned_at',
          'reviewPinnedAt',
        ]),
        'created_at': pick([
          'coach_review_created_at',
          'coachReviewCreatedAt',
          'review_created_at',
          'reviewCreatedAt',
        ]),
        'updated_at': pick([
          'coach_review_updated_at',
          'coachReviewUpdatedAt',
          'review_updated_at',
          'reviewUpdatedAt',
        ]),
        'client_seen_at': pick([
          'coach_review_client_seen_at',
          'coachReviewClientSeenAt',
          'review_client_seen_at',
          'reviewClientSeenAt',
        ]),
        'voice_note_url': pick([
          'coach_review_voice_note_url',
          'coachReviewVoiceNoteUrl',
          'review_voice_note_url',
          'reviewVoiceNoteUrl',
          'voice_note_url',
          'voiceNoteUrl',
          'voice_note',
          'voiceNote',
        ]),
      };
      final hasFlattenedReview =
          parseString(flattened['review_text']) != null ||
          parseString(flattened['voice_note_url']) != null ||
          parseString(flattened['review_status']) != null ||
          parseInt(flattened['coach_user_id']) > 0;
      if (hasFlattenedReview) {
        coachReview = flattened;
      }
    }
    final rawReplies =
        pick(['coach_review_replies', 'coachReviewReplies']) ??
        pick(['review_replies', 'reviewReplies']) ??
        coachReview?['replies'];
    final coachReplies = rawReplies is List
        ? rawReplies
              .whereType<Map>()
              .map(
                (reply) => FormCheckCoachReply.fromJson(
                  Map<String, dynamic>.from(reply),
                ),
              )
              .toList()
        : <FormCheckCoachReply>[];

    return FormCheckSubmission(
      submissionId: topSubmissionId,
      userId: parseInt(
        pick(['user_id', 'userId', 'client_user_id', 'clientUserId']),
      ),
      exerciseId: pick(['exercise_id', 'exerciseId']) == null
          ? null
          : parseInt(pick(['exercise_id', 'exerciseId'])),
      exerciseName: (pick(['exercise_name', 'exerciseName', 'exercise']) ?? '')
          .toString(),
      originalFilename: parseString(
        pick(['original_filename', 'originalFilename', 'filename']),
      ),
      originalVideoUrl: parseString(
        pick([
          'original_video_url',
          'originalVideoUrl',
          'video_url',
          'videoUrl',
        ]),
      ),
      overlayVideoUrl: parseString(
        pick(['overlay_video_url', 'overlayVideoUrl']),
      ),
      mimeType: (pick(['mime_type', 'mimeType']) ?? '').toString(),
      fileSizeBytes: parseInt(pick(['file_size_bytes', 'fileSizeBytes'])),
      durationSeconds: parseDouble(
        pick(['duration_seconds', 'durationSeconds']),
      ),
      status: (pick(['status']) ?? '').toString(),
      consentAccepted: parseBool(pick(['consent_accepted', 'consentAccepted'])),
      savedToLibrary: parseBool(pick(['saved_to_library', 'savedToLibrary'])),
      sharedWithCoach: parseBool(
        pick(['shared_with_coach', 'sharedWithCoach']),
      ),
      sharedCoachUserId:
          pick(['shared_coach_user_id', 'sharedCoachUserId']) == null
          ? null
          : parseInt(pick(['shared_coach_user_id', 'sharedCoachUserId'])),
      sharedAt: parseDate(pick(['shared_at', 'sharedAt'])),
      failureReason: parseString(pick(['failure_reason', 'failureReason'])),
      deleteAfter: parseDate(pick(['delete_after', 'deleteAfter'])),
      createdAt: parseDate(pick(['created_at', 'createdAt'])),
      updatedAt: parseDate(pick(['updated_at', 'updatedAt'])),
      result: FormCheckResultData.fromJson(result),
      coachReview: coachReview == null
          ? null
          : FormCheckCoachReview.fromJson(coachReview),
      coachReviewReplies: coachReplies,
    );
  }
}

class FormCheckListResponse {
  final List<FormCheckSubmission> items;
  final FormCheckUsage usage;

  const FormCheckListResponse({required this.items, required this.usage});
}

class DietFeedbackComment {
  final int commentId;
  final int clientUserId;
  final int coachUserId;
  final String mealDate;
  final int? mealId;
  final int? mealIndex;
  final String? mealTitle;
  final String commentText;
  final String? voiceNoteUrl;
  final bool isPinned;
  final DateTime? pinnedAt;
  final DateTime? clientSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DietFeedbackComment({
    required this.commentId,
    required this.clientUserId,
    required this.coachUserId,
    required this.mealDate,
    this.mealId,
    this.mealIndex,
    this.mealTitle,
    required this.commentText,
    this.voiceNoteUrl,
    required this.isPinned,
    this.pinnedAt,
    this.clientSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DietFeedbackComment.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    String parseString(dynamic value) => value?.toString().trim() ?? '';

    DateTime? parseDate(dynamic value) {
      final raw = parseString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return DietFeedbackComment(
      commentId: parseInt(json['comment_id']),
      clientUserId: parseInt(json['client_user_id']),
      coachUserId: parseInt(json['coach_user_id']),
      mealDate: parseString(json['meal_date']),
      mealId: json['meal_id'] == null ? null : parseInt(json['meal_id']),
      mealIndex: json['meal_index'] == null
          ? null
          : parseInt(json['meal_index']),
      mealTitle: parseString(json['meal_title']).isEmpty
          ? null
          : parseString(json['meal_title']),
      commentText: parseString(json['comment_text']),
      voiceNoteUrl: parseString(json['voice_note_url']).isEmpty
          ? null
          : parseString(json['voice_note_url']),
      isPinned: json['is_pinned'] == true,
      pinnedAt: parseDate(json['pinned_at']),
      clientSeenAt: parseDate(json['client_seen_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class DietFeedbackDocument {
  final int documentId;
  final int clientUserId;
  final int coachUserId;
  final String? documentTitle;
  final String? originalFilename;
  final String? documentUrl;
  final String? mimeType;
  final int fileSizeBytes;
  final DateTime? clientSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DietFeedbackDocument({
    required this.documentId,
    required this.clientUserId,
    required this.coachUserId,
    this.documentTitle,
    this.originalFilename,
    this.documentUrl,
    this.mimeType,
    required this.fileSizeBytes,
    this.clientSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DietFeedbackDocument.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    String parseString(dynamic value) => value?.toString().trim() ?? '';

    DateTime? parseDate(dynamic value) {
      final raw = parseString(value);
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    String? parseNullableString(dynamic value) {
      final normalized = parseString(value);
      return normalized.isEmpty ? null : normalized;
    }

    return DietFeedbackDocument(
      documentId: parseInt(json['document_id']),
      clientUserId: parseInt(json['client_user_id']),
      coachUserId: parseInt(json['coach_user_id']),
      documentTitle: parseNullableString(json['document_title']),
      originalFilename: parseNullableString(json['original_filename']),
      documentUrl: parseNullableString(json['document_url']),
      mimeType: parseNullableString(json['mime_type']),
      fileSizeBytes: parseInt(json['file_size_bytes']),
      clientSeenAt: parseDate(json['client_seen_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class FormCheckFeedbackFeed {
  final int? clientUserId;
  final List<FormCheckSubmission> items;
  final List<FormCheckSubmission> pinnedItems;
  final List<DietFeedbackComment> dietComments;
  final List<DietFeedbackDocument> dietDocuments;

  const FormCheckFeedbackFeed({
    this.clientUserId,
    required this.items,
    required this.pinnedItems,
    required this.dietComments,
    required this.dietDocuments,
  });

  factory FormCheckFeedbackFeed.fromJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    List<FormCheckSubmission> parseItems(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                FormCheckSubmission.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    List<DietFeedbackComment> parseDietComments(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                DietFeedbackComment.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.commentText.trim().isNotEmpty)
          .toList();
    }

    List<DietFeedbackDocument> parseDietDocuments(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                DietFeedbackDocument.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => (item.documentUrl ?? '').trim().isNotEmpty)
          .toList();
    }

    final parsedItems = parseItems(
      pick(['items', 'feedback_items', 'feedbackItems', 'submissions']),
    );
    final hasPinnedItemsKey =
        json.containsKey('pinned_items') ||
        json.containsKey('pinnedItems') ||
        json.containsKey('pinned');
    var parsedPinnedItems = parseItems(
      pick([
        'pinned_items',
        'pinnedItems',
        'pinned',
        'pinned_feedback',
        'pinnedFeedback',
      ]),
    );
    if (!hasPinnedItemsKey && parsedPinnedItems.isEmpty) {
      parsedPinnedItems = parsedItems.where((item) {
        if (item.coachReview?.isPinned == true) return true;
        return item.coachReviewReplies.any((reply) => reply.isPinned);
      }).toList();
    }

    return FormCheckFeedbackFeed(
      clientUserId: parseIntOrNull(
        pick(['client_user_id', 'clientUserId', 'user_id', 'userId']),
      ),
      items: parsedItems,
      pinnedItems: parsedPinnedItems,
      dietComments: parseDietComments(
        pick([
          'diet_comments',
          'dietComments',
          'diet_feedback',
          'dietFeedback',
        ]),
      ),
      dietDocuments: parseDietDocuments(
        pick([
          'diet_documents',
          'dietDocuments',
          'nutrition_documents',
          'nutritionDocuments',
        ]),
      ),
    );
  }
}

class FormCheckService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  static Future<Map<String, String>> _authHeaders() async {
    return AccountStorage.getAuthHeaders();
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

  static Future<FormCheckUsage> fetchUsage() async {
    final res = await http.get(
      _uri('/form-check/usage'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load Form Check usage', res.body),
      );
    }
    return FormCheckUsage.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckListResponse> fetchSubmissions({
    bool savedOnly = false,
    bool includeDeleted = false,
  }) async {
    final res = await http.get(
      _uri('/form-check/submissions', {
        'saved_only': savedOnly ? 'true' : 'false',
        'include_deleted': includeDeleted ? 'true' : 'false',
      }),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load Form Check submissions', res.body),
      );
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawItems = decoded['items'];
    final usage = FormCheckUsage.fromJson(
      (decoded['usage'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => FormCheckSubmission.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <FormCheckSubmission>[];
    return FormCheckListResponse(items: items, usage: usage);
  }

  static Future<FormCheckSubmission> fetchSubmission(int submissionId) async {
    final res = await http.get(
      _uri('/form-check/submissions/$submissionId'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load Form Check submission', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckFeedbackFeed> fetchFeedbackFeed() async {
    final res = await http.get(
      _uri('/form-check/feedback-feed'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to load coach feedback feed', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return FormCheckFeedbackFeed.fromJson(decoded);
    }
    if (decoded is Map) {
      return FormCheckFeedbackFeed.fromJson(Map<String, dynamic>.from(decoded));
    }
    if (decoded is List) {
      final items = decoded
          .whereType<Map>()
          .map(
            (item) =>
                FormCheckSubmission.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final pinnedItems = items.where((item) {
        if (item.coachReview?.isPinned == true) return true;
        return item.coachReviewReplies.any((reply) => reply.isPinned);
      }).toList();
      return FormCheckFeedbackFeed(
        clientUserId: null,
        items: items,
        pinnedItems: pinnedItems,
        dietComments: const [],
        dietDocuments: const [],
      );
    }
    throw Exception('Invalid feedback feed response format.');
  }

  static Future<FormCheckSubmission> createSubmission({
    required File videoFile,
    required String exerciseName,
    required bool consentAccepted,
    required bool saveToLibrary,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/form-check/submissions'),
    );
    request.headers.addAll(await _authHeaders());
    request.fields['exercise_name'] = exerciseName.trim();
    request.fields['consent_accepted'] = consentAccepted ? 'true' : 'false';
    request.fields['save_to_library'] = saveToLibrary ? 'true' : 'false';
    request.files.add(
      await http.MultipartFile.fromPath('video', videoFile.path),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to upload Form Check video', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckSubmission> updateLibraryState({
    required int submissionId,
    required bool savedToLibrary,
  }) async {
    final res = await http.patch(
      _uri('/form-check/submissions/$submissionId/library'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({'saved_to_library': savedToLibrary}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update library state', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<FormCheckSubmission> updateShareState({
    required int submissionId,
    required bool shareWithCoach,
  }) async {
    final res = await http.patch(
      _uri('/form-check/submissions/$submissionId/share'),
      headers: {'Content-Type': 'application/json', ...await _authHeaders()},
      body: jsonEncode({'share_with_coach': shareWithCoach}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to update coach review visibility', res.body),
      );
    }
    return FormCheckSubmission.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<void> deleteSubmission(int submissionId) async {
    final res = await http.delete(
      _uri('/form-check/submissions/$submissionId'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to delete Form Check submission', res.body),
      );
    }
  }
}
