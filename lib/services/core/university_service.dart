import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';

class UniversityService {
  static Future<List<Map<String, dynamic>>> fetchUniversities() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/universities');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Failed to load universities');
    }

    final List data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }
}
