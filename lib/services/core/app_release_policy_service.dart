import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/base_url.dart';

class AppReleasePolicy {
  const AppReleasePolicy({
    required this.platform,
    required this.enabled,
    required this.minimumVersion,
    required this.latestVersion,
    required this.minimumBuild,
    required this.latestBuild,
    required this.updateAvailable,
    required this.updateRequired,
    required this.storeUrl,
    required this.message,
    required this.releaseNotes,
  });

  final String platform;
  final bool enabled;
  final String minimumVersion;
  final String latestVersion;
  final int minimumBuild;
  final int latestBuild;
  final bool updateAvailable;
  final bool updateRequired;
  final String storeUrl;
  final String message;
  final List<String> releaseNotes;

  factory AppReleasePolicy.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawNotes = json['release_notes'];
    return AppReleasePolicy(
      platform: json['platform']?.toString() ?? '',
      enabled: json['enabled'] == true,
      minimumVersion: json['minimum_version']?.toString() ?? '',
      latestVersion: json['latest_version']?.toString() ?? '',
      minimumBuild: asInt(json['minimum_build']),
      latestBuild: asInt(json['latest_build']),
      updateAvailable: json['update_available'] == true,
      updateRequired: json['update_required'] == true,
      storeUrl: json['store_url']?.toString().trim() ?? '',
      message: json['message']?.toString().trim() ?? '',
      releaseNotes: rawNotes is List
          ? rawNotes
                .map((note) => note.toString().trim())
                .where((note) => note.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

/// Fetches the release policy used for iOS update prompts and release notes.
/// Android update discovery remains owned by Google Play's native API.
class AppReleasePolicyService extends ChangeNotifier {
  AppReleasePolicyService._();

  static final AppReleasePolicyService instance = AppReleasePolicyService._();

  static const _dismissedPrefix = 'store_update_dismissed';
  static const _dismissDuration = Duration(days: 1);

  bool _checking = false;
  Completer<void>? _activeCheck;
  AppReleasePolicy? _policy;
  PackageInfo? _packageInfo;
  String? _lastLanguageCode;

  AppReleasePolicy? get policy => _policy;

  bool get isVisible {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    final current = _policy;
    final storeUri = Uri.tryParse(current?.storeUrl ?? '');
    return current != null &&
        current.enabled &&
        current.updateAvailable &&
        storeUri?.scheme == 'https' &&
        storeUri?.host.isNotEmpty == true;
  }

  bool get isRequiredUpdateVisible {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final current = _policy;
    final storeUri = Uri.tryParse(current?.storeUrl ?? '');
    return current != null &&
        current.enabled &&
        current.updateAvailable &&
        current.updateRequired &&
        storeUri?.scheme == 'https' &&
        storeUri?.host.isNotEmpty == true;
  }

  Future<void> initialize({String languageCode = 'en'}) async {
    await checkForUpdate(languageCode: languageCode);
  }

  Future<void> checkForUpdate({
    String languageCode = 'en',
    bool respectDismissal = true,
  }) async {
    if (kIsWeb) return;
    final normalizedLanguage = languageCode.toLowerCase() == 'ar' ? 'ar' : 'en';
    if (_checking) {
      await _activeCheck?.future;
      if (_lastLanguageCode != normalizedLanguage) {
        await checkForUpdate(
          languageCode: normalizedLanguage,
          respectDismissal: respectDismissal,
        );
      }
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _checking = true;
    final activeCheck = Completer<void>();
    _activeCheck = activeCheck;
    try {
      final info = _packageInfo ??= await PackageInfo.fromPlatform();
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final uri = Uri.parse('${ApiConfig.baseUrl}/app/version').replace(
        queryParameters: {
          'platform': platform,
          'current_version': info.version,
          'current_build': info.buildNumber,
          'language': normalizedLanguage,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;

      final next = AppReleasePolicy.fromJson(decoded);
      if (respectDismissal &&
          next.updateAvailable &&
          !next.updateRequired &&
          await _wasDismissedRecently(next)) {
        _policy = AppReleasePolicy(
          platform: next.platform,
          enabled: next.enabled,
          minimumVersion: next.minimumVersion,
          latestVersion: next.latestVersion,
          minimumBuild: next.minimumBuild,
          latestBuild: next.latestBuild,
          updateAvailable: false,
          updateRequired: false,
          storeUrl: next.storeUrl,
          message: next.message,
          releaseNotes: next.releaseNotes,
        );
      } else {
        _policy = next;
      }
      _lastLanguageCode = normalizedLanguage;
      notifyListeners();
    } catch (_) {
      // A release check must never delay or interrupt normal app startup.
    } finally {
      _checking = false;
      if (!activeCheck.isCompleted) activeCheck.complete();
      if (identical(_activeCheck, activeCheck)) _activeCheck = null;
    }
  }

  Future<bool> openStore() async {
    final uri = Uri.tryParse(_policy?.storeUrl ?? '');
    if (uri == null || uri.scheme != 'https') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissForToday() async {
    final current = _policy;
    if (current == null || current.updateRequired) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _dismissalKey(current),
      DateTime.now().millisecondsSinceEpoch,
    );
    _policy = AppReleasePolicy(
      platform: current.platform,
      enabled: current.enabled,
      minimumVersion: current.minimumVersion,
      latestVersion: current.latestVersion,
      minimumBuild: current.minimumBuild,
      latestBuild: current.latestBuild,
      updateAvailable: false,
      updateRequired: false,
      storeUrl: current.storeUrl,
      message: current.message,
      releaseNotes: current.releaseNotes,
    );
    notifyListeners();
  }

  List<String> releaseNotesForInstalledVersion() {
    final current = _policy;
    final info = _packageInfo;
    if (current == null || info == null) return const [];
    if (current.latestVersion != info.version.trim()) return const [];
    final installedBuild = int.tryParse(info.buildNumber);
    if (installedBuild != null &&
        current.latestBuild > 0 &&
        installedBuild != current.latestBuild) {
      return const [];
    }
    return current.releaseNotes;
  }

  String _dismissalKey(AppReleasePolicy policy) =>
      '${_dismissedPrefix}_${policy.platform}_${policy.latestVersion}_${policy.latestBuild}';

  Future<bool> _wasDismissedRecently(AppReleasePolicy policy) async {
    final preferences = await SharedPreferences.getInstance();
    final dismissedAt = preferences.getInt(_dismissalKey(policy));
    if (dismissedAt == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(dismissedAt),
    );
    return !elapsed.isNegative && elapsed < _dismissDuration;
  }
}
