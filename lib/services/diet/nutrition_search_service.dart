import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';

class NutritionSearchService {
  static String baseUrl = ApiConfig.baseUrl;

  static Future<List<Map<String, dynamic>>> searchFoods({
    required String q,
    int limit = 25,
    int offset = 0,
    String? category,
    String? dietTag,
    String? portionType,
  }) async {
    final query = q.trim();
    final uri = Uri.parse('$baseUrl/nutrition/foods').replace(
      queryParameters: <String, String>{
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        if (dietTag != null && dietTag.trim().isNotEmpty) 'diet_tag': dietTag.trim(),
        if (portionType != null && portionType.trim().isNotEmpty) 'portion_type': portionType.trim(),
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? json.decode(res.body) : {};
      throw Exception(body['detail'] ?? 'Failed to search foods');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = data['items'];
    if (items is! List) return [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static Future<List<Map<String, dynamic>>> searchRestaurants({
    required String q,
    int limit = 25,
    int offset = 0,
    String? brand,
  }) async {
    final query = q.trim();
    final uri = Uri.parse('$baseUrl/nutrition/restaurants').replace(
      queryParameters: <String, String>{
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? json.decode(res.body) : {};
      throw Exception(body['detail'] ?? 'Failed to search restaurants');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = data['items'];
    if (items is! List) return [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}

