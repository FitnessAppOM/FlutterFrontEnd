import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';

class ProfileApi {
  static Future<Map<String, dynamic>> fetchProfile(int userId) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    }

    throw Exception("Failed to load profile (${res.statusCode})");
  }

  static Future<String> uploadAvatar(int userId, String filePath) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/profile/$userId/avatar");
    final request = http.MultipartRequest("POST", url);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

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
    final res = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username}),
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
}
