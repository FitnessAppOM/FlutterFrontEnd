import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';

class ExpertQuestionnaireApi {
  static Future<void> submit(Map<String, dynamic> data) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/expert-questionnaire/submit");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return;
    String msg = "Failed to submit questionnaire";
    try {
      final body = jsonDecode(res.body);
      msg = body["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<String> upload(String kind, String filePath) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/expert-questionnaire/upload/$kind");
    final request = http.MultipartRequest("POST", url);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data["url"] ?? "").toString();
    }
    String msg = "Failed to upload file";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }
}
