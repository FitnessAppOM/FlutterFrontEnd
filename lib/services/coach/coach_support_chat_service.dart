import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class CoachSupportChatMessage {
  const CoachSupportChatMessage({
    required this.id,
    required this.threadId,
    required this.senderRole,
    required this.senderName,
    required this.messageType,
    required this.messageText,
    this.senderUserId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int threadId;
  final String senderRole;
  final String senderName;
  final String messageType;
  final String messageText;
  final int? senderUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFromClient => senderRole == 'client';
  bool get isFromCoach => senderRole == 'coach';

  factory CoachSupportChatMessage.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return CoachSupportChatMessage(
      id: parseInt(json['id']),
      threadId: parseInt(json['thread_id'] ?? json['threadId']),
      senderRole: (json['sender_role'] ?? json['senderRole'] ?? 'client')
          .toString()
          .trim()
          .toLowerCase(),
      senderName: (json['sender_name'] ?? json['senderName'] ?? 'User')
          .toString()
          .trim(),
      messageType: (json['message_type'] ?? json['messageType'] ?? 'text')
          .toString()
          .trim()
          .toLowerCase(),
      messageText: (json['message_text'] ?? json['messageText'] ?? '')
          .toString()
          .trim(),
      senderUserId: parseIntOrNull(
        json['sender_user_id'] ?? json['senderUserId'],
      ),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

class CoachSupportChatThread {
  const CoachSupportChatThread({
    required this.id,
    required this.clientUserId,
    required this.coachUserId,
    required this.clientName,
    required this.coachName,
    this.createdAt,
    this.updatedAt,
    this.lastClientMessageAt,
    this.lastCoachMessageAt,
  });

  final int id;
  final int clientUserId;
  final int coachUserId;
  final String clientName;
  final String coachName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastClientMessageAt;
  final DateTime? lastCoachMessageAt;

  factory CoachSupportChatThread.fromJson(Map<String, dynamic> json) {
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

    return CoachSupportChatThread(
      id: parseInt(json['id']),
      clientUserId: parseInt(json['client_user_id'] ?? json['clientUserId']),
      coachUserId: parseInt(json['coach_user_id'] ?? json['coachUserId']),
      clientName: (json['client_name'] ?? json['clientName'] ?? 'Client')
          .toString()
          .trim(),
      coachName: (json['coach_name'] ?? json['coachName'] ?? 'Coach')
          .toString()
          .trim(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      lastClientMessageAt: parseDate(
        json['last_client_message_at'] ?? json['lastClientMessageAt'],
      ),
      lastCoachMessageAt: parseDate(
        json['last_coach_message_at'] ?? json['lastCoachMessageAt'],
      ),
    );
  }
}

class CoachSupportChatSla {
  const CoachSupportChatSla({
    required this.status,
    required this.targetWindowHoursMin,
    required this.targetWindowHoursMax,
    required this.breached,
    required this.isEscalated,
    this.expectedResponseDueAt,
    this.expectedResponseWithinSeconds,
    this.expectedResponseWithinHours,
    this.lastClientMessageAt,
    this.lastCoachMessageAt,
    this.escalatedAt,
  });

  final String status;
  final int targetWindowHoursMin;
  final int targetWindowHoursMax;
  final bool breached;
  final bool isEscalated;
  final DateTime? expectedResponseDueAt;
  final int? expectedResponseWithinSeconds;
  final int? expectedResponseWithinHours;
  final DateTime? lastClientMessageAt;
  final DateTime? lastCoachMessageAt;
  final DateTime? escalatedAt;

  factory CoachSupportChatSla.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
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

    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return CoachSupportChatSla(
      status: (json['status'] ?? 'waiting_for_client').toString().trim(),
      targetWindowHoursMin: parseInt(
        json['target_window_hours_min'] ?? json['targetWindowHoursMin'],
        fallback: 24,
      ),
      targetWindowHoursMax: parseInt(
        json['target_window_hours_max'] ?? json['targetWindowHoursMax'],
        fallback: 48,
      ),
      breached: parseBool(json['breached']),
      isEscalated: parseBool(json['is_escalated'] ?? json['isEscalated']),
      expectedResponseDueAt: parseDate(
        json['expected_response_due_at'] ?? json['expectedResponseDueAt'],
      ),
      expectedResponseWithinSeconds: parseIntOrNull(
        json['expected_response_within_seconds'] ??
            json['expectedResponseWithinSeconds'],
      ),
      expectedResponseWithinHours: parseIntOrNull(
        json['expected_response_within_hours'] ??
            json['expectedResponseWithinHours'],
      ),
      lastClientMessageAt: parseDate(
        json['last_client_message_at'] ?? json['lastClientMessageAt'],
      ),
      lastCoachMessageAt: parseDate(
        json['last_coach_message_at'] ?? json['lastCoachMessageAt'],
      ),
      escalatedAt: parseDate(json['escalated_at'] ?? json['escalatedAt']),
    );
  }
}

class CoachSupportChatState {
  const CoachSupportChatState({
    required this.thread,
    required this.messages,
    required this.sla,
    required this.supportsText,
    required this.supportsImage,
    required this.supportsVideo,
    required this.supportsVoice,
    required this.supportsAutoTranscription,
  });

  final CoachSupportChatThread? thread;
  final List<CoachSupportChatMessage> messages;
  final CoachSupportChatSla sla;
  final bool supportsText;
  final bool supportsImage;
  final bool supportsVideo;
  final bool supportsVoice;
  final bool supportsAutoTranscription;

  factory CoachSupportChatState.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      final raw = value?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) return fallback;
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    final rawThread = json['thread'];
    final thread = rawThread is Map
        ? CoachSupportChatThread.fromJson(Map<String, dynamic>.from(rawThread))
        : null;

    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (e) => CoachSupportChatMessage.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : const <CoachSupportChatMessage>[];

    final rawSla = json['sla'];
    final sla = rawSla is Map
        ? CoachSupportChatSla.fromJson(Map<String, dynamic>.from(rawSla))
        : const CoachSupportChatSla(
            status: 'waiting_for_client',
            targetWindowHoursMin: 24,
            targetWindowHoursMax: 48,
            breached: false,
            isEscalated: false,
          );

    final supports = json['supports'];
    final supportsMap = supports is Map
        ? Map<String, dynamic>.from(supports)
        : const <String, dynamic>{};

    return CoachSupportChatState(
      thread: thread,
      messages: messages,
      sla: sla,
      supportsText: parseBool(supportsMap['text'], fallback: true),
      supportsImage: parseBool(supportsMap['image']),
      supportsVideo: parseBool(supportsMap['video']),
      supportsVoice: parseBool(supportsMap['voice']),
      supportsAutoTranscription: parseBool(
        supportsMap['auto_transcription'] ?? supportsMap['autoTranscription'],
      ),
    );
  }
}

class CoachSupportChatService {
  static Uri _uri(String path) {
    return Uri.parse('${ApiConfig.baseUrl}$path');
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

  static Future<CoachSupportChatState> fetchClientThread() async {
    final res = await http.get(
      _uri('/coach/chat/thread'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to load support chat', res.body));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Failed to load support chat');
    }
    return CoachSupportChatState.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<CoachSupportChatState> sendClientTextMessage({
    required String text,
  }) async {
    final res = await http.post(
      _uri('/coach/chat/messages'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'text': text}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to send support message', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Failed to send support message');
    }
    return CoachSupportChatState.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<CoachSupportChatState> fetchCoachClientThread({
    required int clientUserId,
  }) async {
    final res = await http.get(
      _uri('/coach/chat/coach/clients/$clientUserId'),
      headers: await _authHeaders(),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(_extractError('Failed to load support chat', res.body));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Failed to load support chat');
    }
    return CoachSupportChatState.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<CoachSupportChatState> sendCoachTextMessage({
    required int clientUserId,
    required String text,
  }) async {
    final res = await http.post(
      _uri('/coach/chat/coach/clients/$clientUserId/messages'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'text': text}),
    );
    await _handleAuth(res);
    if (res.statusCode != 200) {
      throw Exception(
        _extractError('Failed to send support message', res.body),
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('Failed to send support message');
    }
    return CoachSupportChatState.fromJson(Map<String, dynamic>.from(decoded));
  }
}
