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
  });

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory FormCheckSubmission.fromJson(Map<String, dynamic> json) {
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

    final resultJson = json['result'];
    final result = resultJson is Map<String, dynamic>
        ? resultJson
        : (resultJson is Map
              ? Map<String, dynamic>.from(resultJson)
              : <String, dynamic>{});

    return FormCheckSubmission(
      submissionId: parseInt(json['submission_id']),
      userId: parseInt(json['user_id']),
      exerciseId: json['exercise_id'] == null
          ? null
          : parseInt(json['exercise_id']),
      exerciseName: (json['exercise_name'] ?? '').toString(),
      originalFilename: json['original_filename']?.toString(),
      originalVideoUrl: json['original_video_url']?.toString(),
      overlayVideoUrl: json['overlay_video_url']?.toString(),
      mimeType: (json['mime_type'] ?? '').toString(),
      fileSizeBytes: parseInt(json['file_size_bytes']),
      durationSeconds: parseDouble(json['duration_seconds']),
      status: (json['status'] ?? '').toString(),
      consentAccepted: json['consent_accepted'] == true,
      savedToLibrary: json['saved_to_library'] == true,
      sharedWithCoach: json['shared_with_coach'] == true,
      sharedCoachUserId: json['shared_coach_user_id'] == null
          ? null
          : parseInt(json['shared_coach_user_id']),
      sharedAt: parseDate(json['shared_at']),
      failureReason: json['failure_reason']?.toString(),
      deleteAfter: parseDate(json['delete_after']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      result: FormCheckResultData.fromJson(result),
    );
  }
}

class FormCheckListResponse {
  final List<FormCheckSubmission> items;
  final FormCheckUsage usage;

  const FormCheckListResponse({required this.items, required this.usage});
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
