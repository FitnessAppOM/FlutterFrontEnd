import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/news_item.dart';

/// Stores news items locally for offline access
class NewsStorage {
  static const _legacyKey = "news_cache";
  static const _legacyLastSyncKey = "news_last_sync";

  static String _normalizedLanguage(String languageCode) =>
      languageCode == 'ar' ? 'ar' : 'en';

  static String _key(String languageCode) =>
      "news_cache_${_normalizedLanguage(languageCode)}";

  static String _lastSyncKey(String languageCode) =>
      "news_last_sync_${_normalizedLanguage(languageCode)}";

  /// Save news items locally
  static Future<void> saveNews(
    List<NewsItem> news, {
    String languageCode = 'en',
  }) async {
    final sp = await SharedPreferences.getInstance();

    // Convert news items to JSON
    final newsJson = news.map((item) => item.toJson()).toList();

    // Save news data
    await sp.setString(_key(languageCode), jsonEncode(newsJson));

    // Save sync timestamp
    await sp.setString(
      _lastSyncKey(languageCode),
      DateTime.now().toIso8601String(),
    );
  }

  /// Load cached news
  static Future<List<NewsItem>> loadNews({String languageCode = 'en'}) async {
    final sp = await SharedPreferences.getInstance();
    final lang = _normalizedLanguage(languageCode);
    // Only English may inherit the old shared cache. Arabic must never show
    // stale English content after the app language changes.
    final raw =
        sp.getString(_key(lang)) ??
        (lang == 'en' ? sp.getString(_legacyKey) : null);

    if (raw == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSync({String languageCode = 'en'}) async {
    final sp = await SharedPreferences.getInstance();
    final lang = _normalizedLanguage(languageCode);
    final raw =
        sp.getString(_lastSyncKey(lang)) ??
        (lang == 'en' ? sp.getString(_legacyLastSyncKey) : null);

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
    await Future.wait([
      sp.remove(_legacyKey),
      sp.remove(_legacyLastSyncKey),
      sp.remove(_key('en')),
      sp.remove(_key('ar')),
      sp.remove(_lastSyncKey('en')),
      sp.remove(_lastSyncKey('ar')),
    ]);
  }
}
