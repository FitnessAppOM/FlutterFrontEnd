import 'dart:convert';

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
  static const _kWhoopLinked = 'whoop_linked';
  static const _kFitbitLinked = 'fitbit_linked';
  static const _kStravaLinked = 'strava_linked';
  static const _kAppleWatchDetected = 'apple_watch_detected';
  static const _kWearableDetectedType = 'wearable_detected_type';
  static const _kSkipDailyJournalPromptOnce = 'skip_daily_journal_prompt_once';
  static const _kProfileEditBlockedUntil = 'profile_edit_blocked_until';
  static const _kDismissDeactivatedPrompt = 'dismiss_deactivated_prompt';
  static String _whoopLinkedKey(int? userId) =>
      userId == null ? _kWhoopLinked : "${_kWhoopLinked}_u$userId";
  static String _fitbitLinkedKey(int? userId) =>
      userId == null ? _kFitbitLinked : "${_kFitbitLinked}_u$userId";
  static String _stravaLinkedKey(int? userId) =>
      userId == null ? _kStravaLinked : "${_kStravaLinked}_u$userId";
  static String _appleWatchDetectedKey(int? userId) => userId == null
      ? _kAppleWatchDetected
      : "${_kAppleWatchDetected}_u$userId";
  static String _wearableDetectedTypeKey(int? userId) => userId == null
      ? _kWearableDetectedType
      : "${_kWearableDetectedType}_u$userId";
  static String _skipDailyJournalPromptOnceKey(int userId) =>
      "${_kSkipDailyJournalPromptOnce}_u$userId";
  static String _profileEditBlockedUntilKey(int userId) =>
      "${_kProfileEditBlockedUntil}_u$userId";
  static String _dismissDeactivatedPromptKey(int userId) =>
      "${_kDismissDeactivatedPrompt}_u$userId";
  static String _avatarPathKey(int? userId) =>
      userId == null ? _kAvatarPath : "${_kAvatarPath}_u$userId";
  static String _avatarUrlKey(int? userId) =>
      userId == null ? _kAvatarUrl : "${_kAvatarUrl}_u$userId";
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
  static final ValueNotifier<int> stravaChange = ValueNotifier(0);
  static final ValueNotifier<int> accountChange = ValueNotifier(0);
  static final ValueNotifier<int> appleWatchChange = ValueNotifier(0);
  static final ValueNotifier<int> trainingChange = ValueNotifier(0);
  static final ValueNotifier<int> dietChange = ValueNotifier(0);
  static final ValueNotifier<int> journalChange = ValueNotifier(0);

  static void notifyWhoopChanged() {
    whoopChange.value++;
  }

  static void notifyStravaChanged() {
    stravaChange.value++;
  }

  static void notifyAccountChanged() {
    accountChange.value++;
  }

  static void notifyAppleWatchChanged() {
    appleWatchChange.value++;
  }

  static void notifyTrainingChanged() {
    trainingChange.value++;
  }

  static void notifyDietChanged() {
    dietChange.value++;
  }

  static void notifyJournalChanged() {
    journalChange.value++;
  }

  static Future<void> setWhoopLinked(bool linked) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    await sp.setBool(_whoopLinkedKey(userId), linked);
  }

  static Future<bool?> getWhoopLinked() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _whoopLinkedKey(userId);
    if (!sp.containsKey(key)) return null;
    return sp.getBool(key);
  }

  static Future<void> setFitbitLinked(bool linked) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    await sp.setBool(_fitbitLinkedKey(userId), linked);
  }

  static Future<bool?> getFitbitLinked() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _fitbitLinkedKey(userId);
    if (!sp.containsKey(key)) return null;
    return sp.getBool(key);
  }

  static Future<void> setStravaLinked(bool linked) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    await sp.setBool(_stravaLinkedKey(userId), linked);
  }

  static Future<bool?> getStravaLinked() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _stravaLinkedKey(userId);
    if (!sp.containsKey(key)) return null;
    return sp.getBool(key);
  }

  static Future<void> setAppleWatchDetected(bool detected) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    await sp.setBool(_appleWatchDetectedKey(userId), detected);
  }

  static Future<bool?> getAppleWatchDetected() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _appleWatchDetectedKey(userId);
    if (!sp.containsKey(key)) return null;
    return sp.getBool(key);
  }

  static Future<void> setWearableDetectedType(String? type) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _wearableDetectedTypeKey(userId);
    if (type == null || type.trim().isEmpty) {
      await sp.remove(key);
      return;
    }
    await sp.setString(key, type.trim().toLowerCase());
  }

  static Future<String?> getWearableDetectedType() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    final key = _wearableDetectedTypeKey(userId);
    final raw = sp.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().toLowerCase();
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
      _kQuestionnaireDone,
      questionnaireDone ?? existingQuestionnaireDone,
    );
    await sp.setBool(
      _kExpertQuestionnaireDone,
      expertQuestionnaireDone ?? existingExpertQuestionnaireDone,
    );
    if (token != null && token.trim().isNotEmpty) {
      await sp.setString(_kToken, token.trim());
    }
    if (authProvider != null && authProvider.trim().isNotEmpty) {
      await sp.setString(_kAuthProvider, authProvider.trim());
    }
    await sp.remove(_dismissDeactivatedPromptKey(userId));
    // Notify after every login so UI (e.g. profile) can refresh with new user_id / token
    notifyAccountChanged();
  }

  static Future<void> _clearMetricsForUser(
    SharedPreferences sp,
    int? userId,
  ) async {
    for (final base in _kMetricsKeys) {
      final key = userId == null ? base : "${base}_u$userId";
      await sp.remove(key);
    }
  }

  static Future<int?> getUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_kUserId);
  }

  static Future<void> markSkipDailyJournalPromptForNextSession({
    int? userId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId == null || effectiveUserId <= 0) return;
    await sp.setBool(_skipDailyJournalPromptOnceKey(effectiveUserId), true);
  }

  static Future<bool> consumeSkipDailyJournalPromptForNextSession({
    int? userId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId == null || effectiveUserId <= 0) return false;
    final key = _skipDailyJournalPromptOnceKey(effectiveUserId);
    final shouldSkip = sp.getBool(key) ?? false;
    if (shouldSkip) {
      await sp.remove(key);
    }
    return shouldSkip;
  }

  static Future<void> setProfileEditBlockedUntil(DateTime until) async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return;
    await sp.setString(
      _profileEditBlockedUntilKey(userId),
      until.toUtc().toIso8601String(),
    );
  }

  static Future<DateTime?> getProfileEditBlockedUntil() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return null;
    final raw = sp.getString(_profileEditBlockedUntilKey(userId));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> clearProfileEditBlockedUntil() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return;
    await sp.remove(_profileEditBlockedUntilKey(userId));
  }

  static Future<void> dismissDeactivatedPrompt() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return;
    await sp.setBool(_dismissDeactivatedPromptKey(userId), true);
  }

  static Future<void> allowDeactivatedPromptAgain() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return;
    await sp.remove(_dismissDeactivatedPromptKey(userId));
  }

  static Future<bool> _isDeactivatedPromptDismissed() async {
    final sp = await SharedPreferences.getInstance();
    final userId = sp.getInt(_kUserId);
    if (userId == null || userId <= 0) return false;
    return sp.getBool(_dismissDeactivatedPromptKey(userId)) ?? false;
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

  static Future<void> setIsExpert(bool isExpert) async {
    final sp = await SharedPreferences.getInstance();
    final previous = sp.getBool(_kIsExpert);
    if (previous == isExpert) return;
    await sp.setBool(_kIsExpert, isExpert);
    notifyAccountChanged();
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
  static Future<Map<String, dynamic>> _decodeAuthPayload(
    String? rawBody,
  ) async {
    if (rawBody == null || rawBody.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static bool _looksDeactivatedPayload(Map<String, dynamic> payload) {
    final status = payload['status']?.toString().toLowerCase().trim() ?? '';
    final state = payload['state']?.toString().toLowerCase().trim() ?? '';
    final detail = payload['detail']?.toString().toLowerCase() ?? '';
    final message = payload['message']?.toString().toLowerCase() ?? '';
    final combined = "$status $state $detail $message";
    return combined.contains('deactivated') ||
        combined.contains('reactivate') ||
        combined.contains('reactivable');
  }

  static bool _looksDeletedPayload(Map<String, dynamic> payload) {
    final status = payload['status']?.toString().toLowerCase().trim() ?? '';
    final detail = payload['detail']?.toString().toLowerCase() ?? '';
    final message = payload['message']?.toString().toLowerCase() ?? '';
    final combined = "$status $detail $message";
    if (status == 'deleted' || status == 'not_found') return true;
    return (combined.contains('account') || combined.contains('user')) &&
        (combined.contains('not found') ||
            combined.contains('deleted') ||
            combined.contains('no longer exists'));
  }

  /// Handles auth lifecycle statuses from API responses:
  /// - 401 => clear session + onUnauthorized
  /// - 403 deactivated => onDeactivated
  static Future<bool> handleAuthStatus(
    int statusCode, {
    String? responseBody,
  }) async {
    if (statusCode == 401) {
      await clearSession();
      onUnauthorized?.call();
      return true;
    }

    if (statusCode == 403) {
      final payload = await _decodeAuthPayload(responseBody);
      // Only treat a 403 as "deactivated" when the server EXPLICITLY says so.
      // A bodyless/ambiguous 403 must NOT trigger the restore screen, which
      // previously fabricated a deactivated state and showed a stale "restore
      // account" prompt for already-deleted accounts.
      if (payload.isEmpty || !_looksDeactivatedPayload(payload)) {
        return false;
      }
      final dismissed = await _isDeactivatedPromptDismissed();
      if (dismissed) {
        return false;
      }
      onDeactivated?.call(payload);
      return true;
    }

    if (statusCode == 404) {
      final payload = await _decodeAuthPayload(responseBody);
      if (payload.isNotEmpty && _looksDeletedPayload(payload)) {
        await clearSession();
        onUnauthorized?.call();
        return true;
      }
    }

    return false;
  }

  /// Call when a protected API returns 401: clears session and invokes onUnauthorized (e.g. navigate to login).
  static Future<void> handle401(int statusCode) async {
    await handleAuthStatus(statusCode);
  }

  /// Set from app (e.g. main.dart) to navigate to login when session expires (401).
  static void Function()? onUnauthorized;
  static void Function(Map<String, dynamic>)? onDeactivated;

  static Future<void> setName(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, name);
  }

  static Future<void> setAvatarPath(String path, {int? userId}) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId != null && effectiveUserId > 0) {
      await sp.setString(_avatarPathKey(effectiveUserId), path);
      return;
    }
    await sp.setString(_kAvatarPath, path);
  }

  static Future<String?> getAvatarPath({int? userId}) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId != null && effectiveUserId > 0) {
      final value = sp.getString(_avatarPathKey(effectiveUserId));
      if (value == null || value.trim().isEmpty) return null;
      return value;
    }
    return sp.getString(_kAvatarPath);
  }

  static Future<void> setAvatarUrl(String url, {int? userId}) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId != null && effectiveUserId > 0) {
      await sp.setString(_avatarUrlKey(effectiveUserId), url);
      return;
    }
    await sp.setString(_kAvatarUrl, url);
  }

  static Future<String?> getAvatarUrl({int? userId}) async {
    final sp = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? sp.getInt(_kUserId);
    if (effectiveUserId != null && effectiveUserId > 0) {
      final value = sp.getString(_avatarUrlKey(effectiveUserId));
      if (value == null || value.trim().isEmpty) return null;
      return value;
    }
    return sp.getString(_kAvatarUrl);
  }

  static Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    final currentUserId = sp.getInt(_kUserId);

    // Only remove session-related values
    await sp.remove(_kUserId); // logged-in identity
    await sp.remove(_kToken); // JWT/session token
    await sp.remove(_kVerified); // verification flag
    await sp.remove(_kIsExpert);
    await sp.remove(_kQuestionnaireDone);
    await sp.remove(_kExpertQuestionnaireDone);
    await sp.remove(_kAvatarUrl);
    await sp.remove(_kAvatarPath);
    if (currentUserId != null) {
      await sp.remove(_avatarUrlKey(currentUserId));
      await sp.remove(_avatarPathKey(currentUserId));
      await sp.remove(_whoopLinkedKey(currentUserId));
      await sp.remove(_fitbitLinkedKey(currentUserId));
      await sp.remove(_stravaLinkedKey(currentUserId));
      await sp.remove(_appleWatchDetectedKey(currentUserId));
      await sp.remove(_wearableDetectedTypeKey(currentUserId));
      await sp.remove(_skipDailyJournalPromptOnceKey(currentUserId));
      await sp.remove(_profileEditBlockedUntilKey(currentUserId));
      await sp.remove(_dismissDeactivatedPromptKey(currentUserId));
    }
    await sp.remove(_kWhoopLinked);
    await sp.remove(_kFitbitLinked);
    await sp.remove(_kStravaLinked);
    await sp.remove(_kAppleWatchDetected);
    await sp.remove(_kWearableDetectedType);

    notifyAccountChanged();
  }

  static Future<void> clearSessionOnly() async {
    final sp = await SharedPreferences.getInstance();
    final currentUserId = sp.getInt(_kUserId);
    await sp.remove(_kToken);
    await sp.remove(_kUserId);
    if (currentUserId != null) {
      await sp.remove(_whoopLinkedKey(currentUserId));
      await sp.remove(_fitbitLinkedKey(currentUserId));
      await sp.remove(_stravaLinkedKey(currentUserId));
      await sp.remove(_appleWatchDetectedKey(currentUserId));
      await sp.remove(_wearableDetectedTypeKey(currentUserId));
      await sp.remove(_skipDailyJournalPromptOnceKey(currentUserId));
      await sp.remove(_profileEditBlockedUntilKey(currentUserId));
      await sp.remove(_dismissDeactivatedPromptKey(currentUserId));
    }
    await sp.remove(_kWhoopLinked);
    await sp.remove(_kFitbitLinked);
    await sp.remove(_kStravaLinked);
    await sp.remove(_kAppleWatchDetected);
    await sp.remove(_kWearableDetectedType);
    // Keep email + name + verified → so “Login as…” still works
    notifyAccountChanged();
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    final currentUserId = sp.getInt(_kUserId);
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
    if (currentUserId != null) {
      await sp.remove(_avatarUrlKey(currentUserId));
      await sp.remove(_avatarPathKey(currentUserId));
      await sp.remove(_whoopLinkedKey(currentUserId));
      await sp.remove(_fitbitLinkedKey(currentUserId));
      await sp.remove(_stravaLinkedKey(currentUserId));
      await sp.remove(_appleWatchDetectedKey(currentUserId));
      await sp.remove(_wearableDetectedTypeKey(currentUserId));
      await sp.remove(_skipDailyJournalPromptOnceKey(currentUserId));
      await sp.remove(_profileEditBlockedUntilKey(currentUserId));
      await sp.remove(_dismissDeactivatedPromptKey(currentUserId));
    }
    await sp.remove(_kWhoopLinked);
    await sp.remove(_kFitbitLinked);
    await sp.remove(_kStravaLinked);
    await sp.remove(_kAppleWatchDetected);
    await sp.remove(_kWearableDetectedType);
    notifyAccountChanged();
  }
}
