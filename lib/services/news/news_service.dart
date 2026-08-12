import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../models/news_item.dart';
import 'news_storage.dart';

class NewsApi {
  static Future<List<NewsItem>> fetchNews({
    int limit = 20,
    String languageCode = 'en',
  }) async {
    final lang = languageCode == 'ar' ? 'ar' : 'en';
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/news",
      ).replace(queryParameters: {'limit': '$limit', 'lang': lang});
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final news = data
            .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
            .toList();

        // Cache news for offline access
        await NewsStorage.saveNews(news, languageCode: lang);

        return news;
      }
      throw Exception("Failed to load news (${res.statusCode})");
    } catch (e) {
      // If network fails, try loading from cache
      final cached = await NewsStorage.loadNews(languageCode: lang);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  /// Load news from cache (for offline use)
  static Future<List<NewsItem>> fetchNewsFromCache({
    String languageCode = 'en',
  }) async {
    return NewsStorage.loadNews(languageCode: languageCode);
  }
}
