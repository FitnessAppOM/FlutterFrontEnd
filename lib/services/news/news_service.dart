import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../models/news_item.dart';
import 'news_storage.dart';

class NewsApi {
  static Future<List<NewsItem>> fetchNews({int limit = 20}) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/news?limit=$limit");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final news = data.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
        
        // Cache news for offline access
        await NewsStorage.saveNews(news);
        
        return news;
      }
      throw Exception("Failed to load news (${res.statusCode})");
    } catch (e) {
      // If network fails, try loading from cache
      final cached = await NewsStorage.loadNews();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Load news from cache (for offline use)
  static Future<List<NewsItem>> fetchNewsFromCache() async {
    return await NewsStorage.loadNews();
  }
}
