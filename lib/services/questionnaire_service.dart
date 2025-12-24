import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/base_url.dart';
class QuestionnaireApi {
  static String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> submitQuestionnaire(
      Map<String, String> data) async {
    final url = Uri.parse("$baseUrl/questionnaire/");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to submit questionnaire: ${response.body}");
    }
  }
}
