import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ProfileApi {
  static Future<Map<String, dynamic>> fetchProfile(int userId, {String? lang}) async {
    final langQuery = (lang != null && lang.isNotEmpty) ? "?lang=$lang" : "";
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId$langQuery");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    }

    throw Exception("Failed to load profile (${res.statusCode})");
  }

  static Future<String> uploadAvatar(int userId, String filePath) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/avatar");
    final request = http.MultipartRequest("POST", url);
    final auth = await AccountStorage.getAuthHeaders();
    request.headers.addAll(auth);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    await AccountStorage.handle401(res.statusCode);
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
    final headers = {"Content-Type": "application/json", ...await AccountStorage.getAuthHeaders()};
    final res = await http.patch(
      url,
      headers: headers,
      body: jsonEncode({"username": username}),
    );

    await AccountStorage.handle401(res.statusCode);
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

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/update");
    final headers = {"Content-Type": "application/json", ...await AccountStorage.getAuthHeaders()};
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) {
      if (res.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    String msg = "Failed to update profile";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<void> deleteAccount(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId");
    final headers = await AccountStorage.getAuthHeaders();
    final res = await http.delete(url, headers: headers);

    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) return;

    String msg = "Failed to delete account";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }
}
