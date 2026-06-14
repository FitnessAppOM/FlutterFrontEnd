import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'profile_storage.dart';

class ProfileUpdateCooldownException implements Exception {
  final String detail;
  final DateTime? nextAllowedAt;

  ProfileUpdateCooldownException({required this.detail, this.nextAllowedAt});

  @override
  String toString() => detail;
}

class ProfileApi {
  static String? _normalizeAvatarUrl(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? "";
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.startsWith("http://") || lower.startsWith("https://")) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final baseUri = Uri.parse(base.endsWith("/") ? base : "$base/");
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static DateTime? _extractDateTimeFromText(String text) {
    final iso = RegExp(
      r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+\-]\d{2}:\d{2})?)',
    ).firstMatch(text);
    if (iso != null) return DateTime.tryParse(iso.group(1)!);

    final dateOnly = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(text);
    if (dateOnly != null) return DateTime.tryParse(dateOnly.group(1)!);
    return null;
  }

  static Future<Map<String, dynamic>> fetchProfile(
    int userId, {
    String? lang,
  }) async {
    final langQuery = (lang != null && lang.isNotEmpty) ? "?lang=$lang" : "";
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId$langQuery");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final normalizedAvatar = _normalizeAvatarUrl(data["avatar_url"]);
      if (normalizedAvatar != null) {
        data["avatar_url"] = normalizedAvatar;
        try {
          await AccountStorage.setAvatarUrl(normalizedAvatar, userId: userId);
        } catch (_) {}
      }
      try {
        await ProfileStorage.saveProfile(data, userId: userId);
      } catch (_) {}
      return data;
    }

    if (res.statusCode == 403) {
      final data = _decodeMap(res.body);
      final detail = data["detail"]?.toString() ?? "Account is deactivated";
      throw Exception(detail);
    }

    throw Exception("Failed to load profile (${res.statusCode})");
  }

  static Future<Map<String, dynamic>> detachCoach({
    required int expertUserId,
  }) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/coach/connections/$expertUserId",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.delete(url, headers: headers);

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode == 200) {
      return _decodeMap(res.body);
    }

    String msg = "Failed to detach coach";
    try {
      final data = _decodeMap(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> connectCoachByCode({
    required String code,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/coach/connections/by-code");
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"code": code}),
    );

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode == 200) {
      return _decodeMap(res.body);
    }

    String msg = "Failed to connect coach";
    try {
      final data = _decodeMap(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> reportCoach({
    required int expertUserId,
    required String reason,
  }) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/coach/connections/$expertUserId/report",
    );
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"reason": reason.trim()}),
    );

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );

    if (res.statusCode == 200) {
      return _decodeMap(res.body);
    }

    String msg = "Failed to report coach";
    try {
      final data = _decodeMap(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<String> uploadAvatar(int userId, String filePath) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/avatar");
    final request = http.MultipartRequest("POST", url);
    final auth = await AccountStorage.getAuthHeaders();
    request.headers.addAll(auth);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data["avatar_url"] ?? "").toString();
    }

    String msg = "Failed to upload avatar";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<String> updateUsername(int userId, String username) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/username");
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.patch(
      url,
      headers: headers,
      body: jsonEncode({"username": username}),
    );

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data["username"] ?? username).toString();
    }

    String msg = "Failed to update username";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final sessionUserId = await AccountStorage.getUserId();
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/update");
    final headers = {
      "Content-Type": "application/json",
      ...await AccountStorage.getAuthHeaders(),
    };
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) {
      if (res.body.isEmpty) return <String, dynamic>{};
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        try {
          await ProfileStorage.saveProfile(data, userId: sessionUserId);
        } catch (_) {}
        return data;
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    if (res.statusCode == 429) {
      final data = _decodeMap(res.body);
      final detail = data["detail"]?.toString() ?? "Profile update cooldown";
      final next = _extractDateTimeFromText(detail);
      throw ProfileUpdateCooldownException(detail: detail, nextAllowedAt: next);
    }

    String msg = "Failed to update profile";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> deleteAccount(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.delete(url, headers: headers);

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200 || res.statusCode == 202) {
      // Clear the cached token/email so the device stops acting on behalf of
      // the deleted account (prevents a stale "restore account" prompt later).
      await AccountStorage.clearSession();
      return _decodeMap(res.body);
    }

    String msg = "Failed to delete account";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> deactivateAccount(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/deactivate");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.post(url, headers: headers);

    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) {
      // Stop the device from acting on behalf of the now-deactivated account.
      // Leaving the cached token/email caused a stale "restore account" prompt
      // on next launch even after the account was removed server-side.
      await AccountStorage.clearSession();
      return _decodeMap(res.body);
    }

    String msg = "Failed to deactivate account";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> fetchAccountStatus(int userId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/profile/$userId/account-status",
    );
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) return _decodeMap(res.body);

    final data = _decodeMap(res.body);
    throw Exception(
      data["detail"]?.toString() ?? "Failed to load account status",
    );
  }

  static Future<Map<String, dynamic>> requestReactivation(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/reactivate");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.post(url, headers: headers);
    await AccountStorage.handleAuthStatus(
      res.statusCode,
      responseBody: res.body,
    );
    if (res.statusCode == 200) return _decodeMap(res.body);
    if (res.statusCode == 410) {
      throw Exception("Account can no longer be restored");
    }
    if (res.statusCode == 404) {
      throw Exception("Account not found");
    }
    final data = _decodeMap(res.body);
    throw Exception(data["detail"]?.toString() ?? "Request failed");
  }

  static Future<Map<String, dynamic>> confirmReactivation(
    String email,
    String code,
  ) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/auth/reactivate/confirm");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "code": code}),
    );
    if (res.statusCode == 410) {
      throw Exception("Account can no longer be restored");
    }
    if (res.statusCode == 200) return _decodeMap(res.body);
    final data = _decodeMap(res.body);
    throw Exception(data["detail"]?.toString() ?? "Reactivation failed");
  }
}
