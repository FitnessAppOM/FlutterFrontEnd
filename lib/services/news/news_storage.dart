import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/news_item.dart';

/// Stores news items locally for offline access
class NewsStorage {
  static const _key = "news_cache";
  static const _lastSyncKey = "news_last_sync";

  /// Save news items locally
  static Future<void> saveNews(List<NewsItem> news) async {
    final sp = await SharedPreferences.getInstance();
    
    // Convert news items to JSON
    final newsJson = news.map((item) => item.toJson()).toList();
    
    // Save news data
    await sp.setString(_key, jsonEncode(newsJson));
    
    // Save sync timestamp
    await sp.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Load cached news
  static Future<List<NewsItem>> loadNews() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);

    if (raw == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSync() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_lastSyncKey);

    if (raw == null) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Clear cached news
  static Future<void> clearNews() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
    await sp.remove(_lastSyncKey);
  }
}
