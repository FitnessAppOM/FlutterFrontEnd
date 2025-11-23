import 'package:http/http.dart' as http;
import 'dart:convert';

class QuestionnaireApi {
  static const String baseUrl = "http://10.0.2.2:8000";

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
