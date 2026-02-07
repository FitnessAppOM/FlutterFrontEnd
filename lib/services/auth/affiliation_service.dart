import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/base_url.dart';

class AffiliationApi {
  static Future<List<String>> fetchCategories() async {
    final url = Uri.parse("${ApiConfig.baseUrl}/affiliations/categories");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((c) => c.toString()).toList();
    }

    throw Exception("Failed to load affiliation categories");
  }

  static Future<List<Map<String, dynamic>>> fetchByCategory(
      String category) async {
    final url = Uri.parse(
        "${ApiConfig.baseUrl}/affiliations/by-category?category=${Uri.encodeQueryComponent(category)}");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data
          .map((item) => {
                "id": item["id"],
                "name": item["name"],
                "category": item["category"],
              })
          .toList();
    }

    String msg = "Failed to load affiliations";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }
  static Future<void> requestAffiliation({
    required String name,
    required String category,
    required String source,
  }) async {
    final res = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/affiliations/request"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "category": category,
        "source": source,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Failed to submit affiliation request");
    }
  }


}
