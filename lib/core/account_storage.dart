import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountStorage {
  static const _kUserId = 'user_id';
  static const _kEmail = 'last_email';
  static const _kName = 'last_name';
  static const _kVerified = 'last_verified';
  static const _kToken = 'auth_token';
  static const _kIsExpert = 'is_expert';
  static const _kQuestionnaireDone = 'questionnaire_done';
  static const _kExpertQuestionnaireDone = 'expert_questionnaire_done';
  static const _kAvatarPath = 'avatar_path';
  static const _kAvatarUrl = 'avatar_url';
  static const _kAuthProvider = 'auth_provider';
  static const _kMetricsKeys = [
    "manual_steps_entries",
    "manual_calories_entries",
    "manual_sleep_entries",
    "water_intake_entries",
    "water_goal_liters",
    "daily_metrics_last_push_date",
  ];

  // In-app signal to refresh Whoop status across screens.
  static final ValueNotifier<int> whoopChange = ValueNotifier(0);
  static final ValueNotifier<int> accountChange = ValueNotifier(0);
  static final ValueNotifier<int> trainingChange = ValueNotifier(0);

  static void notifyWhoopChanged() {
    whoopChange.value++;
  }

  static void notifyAccountChanged() {
    accountChange.value++;
  }

  static void notifyTrainingChanged() {
    trainingChange.value++;
  }

  // Save everything after login (do not call with userId <= 0 or empty token)
  static Future<void> saveUserSession({
    required int userId,
    required String email,
    required String name,
    required bool verified,
    String? token,
    bool? isExpert,
    bool? questionnaireDone,
    bool? expertQuestionnaireDone,
    String? authProvider,
  }) async {
    if (userId <= 0) return; // Never overwrite with invalid id
    final sp = await SharedPreferences.getInstance();
    final previousUserId = sp.getInt(_kUserId);
    final previousEmail = sp.getString(_kEmail);
    final isDifferentUser =
        (previousUserId != null && previousUserId != userId) ||
        (previousEmail != null && previousEmail != email);

    final existingQuestionnaireDone = sp.getBool(_kQuestionnaireDone) ?? false;
    final existingExpertQuestionnaireDone =
        sp.getBool(_kExpertQuestionnaireDone) ?? false;

    // Reset avatar cache when switching accounts
    if (isDifferentUser) {
      await sp.remove(_kAvatarUrl);
      await sp.remove(_kAvatarPath);
      await _clearMetricsForUser(sp, previousUserId);
      await _clearMetricsForUser(sp, null); // clear any unscoped cache
    }

    await sp.setInt(_kUserId, userId);
    await sp.setString(_kEmail, email);
    await sp.setString(_kName, name);
    await sp.setBool(_kVerified, verified);
    if (isExpert != null) {
      await sp.setBool(_kIsExpert, isExpert);
    }
    // Preserve questionnaire completion unless explicitly provided
    await sp.setBool(
        _kQuestionnaireDone, questionnaireDone ?? existingQuestionnaireDone);
    await sp.setBool(_kExpertQuestionnaireDone,
        expertQuestionnaireDone ?? existingExpertQuestionnaireDone);
    if (token != null && token.trim().isNotEmpty) {
      await sp.setString(_kToken, token.trim());
    }
    if (authProvider != null && authProvider.trim().isNotEmpty) {
      await sp.setString(_kAuthProvider, authProvider.trim());
    }
    // Notify after every login so UI (e.g. profile) can refresh with new user_id / token
    notifyAccountChanged();
  }

  static Future<void> _clearMetricsForUser(SharedPreferences sp, int? userId) async {
    for (final base in _kMetricsKeys) {
      final key = userId == null ? base : "${base}_u$userId";
      await sp.remove(key);
    }
  }

  static Future<int?> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }

  static Future<String?> getEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> getName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kName);
  }

  static Future<bool> isVerified() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kVerified) ?? false;
  }

  static Future<bool> isExpert() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kIsExpert) ?? false;
  }

  static Future<String?> getAuthProvider() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAuthProvider);
  }

  static Future<void> setQuestionnaireDone(bool done) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kQuestionnaireDone, done);
  }

  static Future<bool> isQuestionnaireDone() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kQuestionnaireDone) ?? false;
  }

  static Future<void> setExpertQuestionnaireDone(bool done) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kExpertQuestionnaireDone, done);
  }

  static Future<bool> isExpertQuestionnaireDone() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kExpertQuestionnaireDone) ?? false;
  }

  /// JWT access token returned by login / Google login. Used for Authorization header on protected APIs.
  static Future<String?> getAccessToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  /// Headers to send with protected API requests. Empty if no token.
  /// Uses exact token string, trimmed (no extra spaces) as required by backend.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    final t = token?.trim();
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }

  /// Call when a protected API returns 401: clears session and invokes onUnauthorized (e.g. navigate to login).
  static Future<void> handle401(int statusCode) async {
    if (statusCode == 401) {
      await clearSession();
      onUnauthorized?.call();
    }
  }

  /// Set from app (e.g. main.dart) to navigate to login when session expires (401).
  static void Function()? onUnauthorized;

  static Future<void> setName(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, name);
  }

  static Future<void> setAvatarPath(String path) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAvatarPath, path);
  }

  static Future<String?> getAvatarPath() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAvatarPath);
  }

  static Future<void> setAvatarUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAvatarUrl, url);
  }

  static Future<String?> getAvatarUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAvatarUrl);
  }

static Future<void> clearSession() async {
  final sp = await SharedPreferences.getInstance();

  // Only remove session-related values
  await sp.remove(_kUserId);     // logged-in identity
  await sp.remove(_kToken);      // JWT/session token
  await sp.remove(_kVerified);   // verification flag
  await sp.remove(_kIsExpert);
  await sp.remove(_kQuestionnaireDone);
  await sp.remove(_kExpertQuestionnaireDone);
  await sp.remove(_kAvatarUrl);
  await sp.remove(_kAvatarPath);

  notifyAccountChanged();

}

static Future<void> clearSessionOnly() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove(_kToken);
  await sp.remove(_kUserId);
  // Keep email + name + verified → so “Login as…” still works
  notifyAccountChanged();
}

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kEmail);
    await sp.remove(_kName);
    await sp.remove(_kVerified);
    await sp.remove(_kToken);
    await sp.remove(_kAuthProvider);
    await sp.remove(_kIsExpert);
    await sp.remove(_kQuestionnaireDone);
    await sp.remove(_kExpertQuestionnaireDone);
    await sp.remove(_kAvatarUrl);
    await sp.remove(_kAvatarPath);
    notifyAccountChanged();
  }
}
