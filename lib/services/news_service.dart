import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/base_url.dart';
import '../models/news_item.dart';

class NewsApi {
  static Future<List<NewsItem>> fetchNews({int limit = 20}) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/news?limit=$limit");
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception("Failed to load news (${res.statusCode})");
  }
}
