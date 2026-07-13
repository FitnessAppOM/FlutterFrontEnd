import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../core/locale_controller.dart';
import 'ForgetPassword/forgot_password_page.dart';
import '../services/auth/profile_service.dart';
import '../core/account_storage.dart';
import '../TaqaUI/components/taqa_community_option_picker_sheet.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_log_entry_card.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_segmented_toggle_button.dart';
import '../TaqaUI/components/taqa_switch.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../core/user_friendly_error.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/base_url.dart';
import '../consents/consent_manager.dart';
import '../auth/expert_questionnaire.dart';
import '../services/coach/coach_habit_reminder_settings_service.dart';
import '../services/coach/progression_review_service.dart';
import '../services/core/daily_provider_push_service.dart';
import '../services/core/notification_service.dart';
import '../services/health/apple_watch_detection_service.dart';
import '../services/whoop/whoop_daily_sync.dart';
import '../services/whoop/whoop_latest_service.dart';
import '../services/auth/profile_storage.dart';
import '../screens/welcome.dart';
import '../screens/account_restore_page.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9._-]+$');
  bool _updatingAvatar = false;
  bool _deletingAccount = false;
  bool _deactivatingAccount = false;
  bool _isDeactivated = false;
  bool _isExpert = false;
  bool _expertFlagReady = false;
  String? _expertProfileStatus;
  String? _scheduledPurgeAtDisplay;
  String? _email;
  String? _authProvider;
  bool _expertQuestionnaireDone = false;
  bool _whoopLinked = false;
  bool _whoopLoading = false;
  bool _fitbitLinked = false;
  bool _fitbitLoading = false;
  bool _fitbitAuthInFlight = false;
  bool _stravaLinked = false;
  bool _stravaLoading = false;
  bool _stravaAuthInFlight = false;
  bool? _appleWatchDetected;
  String? _wearableDetectedType;
  bool _appleWatchChecking = false;

  bool _isAuthCancelled(Object e) {
    if (e is PlatformException) {
      final code = e.code.toLowerCase();
      if (code.contains('cancel')) return true;
      final msg = (e.message ?? '').toLowerCase();
      return msg.contains('cancel');
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('cancel');
  }

  String get _langCode => localeController.locale.languageCode;

  void _changeLanguage(Locale locale) {
    localeController.setLocale(locale);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadEmail();
    _loadAuthProvider();
    _loadExpertFlag();
    _loadWhoopStatus();
    _loadFitbitStatus();
    _loadStravaStatus();
    _loadAppleWatchStatus();
    _refreshAccountStatus();
    AccountStorage.accountChange.addListener(_handleAccountChanged);
  }

  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showTaqaInfoDialog(
      context: context,
      title: t.translate("settings"),
      message: message,
      confirmLabel: t.translate("ok"),
    );
  }

  Future<void> _showJwtTokenDialog() async {
    final t = AppLocalizations.of(context);
    final token = await AccountStorage.getAccessToken();
    if (!mounted) return;
    final display = (token == null || token.trim().isEmpty)
        ? t.translate("jwt_token_missing")
        : token.trim();

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate("jwt_token_title"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  display,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.translate("common_close")),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (token == null || token.trim().isEmpty)
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: token.trim()),
                                );
                                if (!context.mounted) return;
                                AppToast.show(
                                  context,
                                  t.translate("jwt_token_copied"),
                                  type: AppToastType.success,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Copy"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    AccountStorage.accountChange.removeListener(_handleAccountChanged);
    super.dispose();
  }

  void _handleAccountChanged() {
    if (!mounted) return;
    setState(() {
      // Keep current wearable link states while reloading to avoid visual flicker.
      _appleWatchDetected = null;
      _wearableDetectedType = null;
      _appleWatchChecking = false;
    });
    _loadEmail();
    _loadAuthProvider();
    _loadExpertFlag();
    _loadWhoopStatus();
    _loadFitbitStatus();
    _loadStravaStatus();
    _loadAppleWatchStatus();
    _refreshAccountStatus();
  }

  String? _normalizeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
  }

  Future<void> _refreshAccountStatus() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0 || !mounted) return;
    try {
      final data = await ProfileApi.fetchAccountStatus(userId);
      final status = (data["status"] ?? "").toString().toLowerCase().trim();
      if (!mounted) return;
      setState(() {
        _isDeactivated = status == "deactivated";
        _scheduledPurgeAtDisplay = _normalizeDate(
          data["scheduled_purge_at"]?.toString(),
        );
      });
    } catch (_) {}
  }

  Future<void> _loadEmail() async {
    final email = await AccountStorage.getEmail();
    if (mounted) {
      setState(() {
        _email = email;
      });
    }
  }

  Future<void> _loadAuthProvider() async {
    final provider = await AccountStorage.getAuthProvider();
    if (mounted) {
      setState(() {
        _authProvider = provider;
      });
    }
  }

  Future<void> _loadExpertFlag() async {
    // Show the locally cached answer immediately (fast, no network) so
    // coach-only sections (e.g. "Coach") don't pop in/out on every visit —
    // only refresh from the server quietly afterwards, in the background.
    var done = await AccountStorage.isExpertQuestionnaireDone();
    var isExpert = await AccountStorage.isExpert();
    String? expertProfileStatus;

    try {
      final cachedProfile = await ProfileStorage.loadProfile();
      final rawCached = (cachedProfile?["expert_profile_status"] ?? "")
          .toString()
          .trim()
          .toLowerCase();
      expertProfileStatus = rawCached.isEmpty ? null : rawCached;
      final cachedFilledExpert =
          cachedProfile?["filled_expert_questionnaire"] == true;
      final cachedIsExpert = cachedProfile?["is_expert"] == true;
      done = done || cachedFilledExpert;
      isExpert = isExpert || cachedIsExpert;
    } catch (_) {
      // Ignore cache parse failures.
    }

    if (mounted) {
      setState(() {
        _expertQuestionnaireDone = done;
        _isExpert = isExpert;
        _expertProfileStatus = expertProfileStatus;
        _expertFlagReady = true;
      });
    }

    final userId = await AccountStorage.getUserId();
    if (userId != null && userId > 0) {
      try {
        if (!mounted) return;
        final lang = AppLocalizations.of(context).locale.languageCode;
        final profile = await ProfileApi.fetchProfile(userId, lang: lang);
        final filledExpertQuestionnaire =
            profile["filled_expert_questionnaire"] == true;
        final rawStatus = (profile["expert_profile_status"] ?? "")
            .toString()
            .trim()
            .toLowerCase();
        expertProfileStatus = rawStatus.isEmpty ? null : rawStatus;
        done = filledExpertQuestionnaire;
        isExpert = profile["is_expert"] == true;
        await AccountStorage.setExpertQuestionnaireDone(done);
        await AccountStorage.setIsExpert(isExpert);
      } catch (_) {
        // Keep existing fallback behavior when profile API isn't reachable.
        return;
      }
    } else {
      return;
    }
    if (mounted) {
      setState(() {
        _expertQuestionnaireDone = done;
        _isExpert = isExpert;
        _expertProfileStatus = expertProfileStatus;
        _expertFlagReady = true;
      });
    }
  }

  bool get _showBeExpertButton {
    if (!_expertFlagReady) return false;
    if (_isExpert || _expertQuestionnaireDone) return false;
    final status = (_expertProfileStatus ?? "").trim().toLowerCase();
    if (status.isEmpty) return true; // No expert profile yet.
    return status == "rejected" ||
        status == "refused" ||
        status == "suspended" ||
        status == "revoked" ||
        status == "banned";
  }

  Future<void> _loadWhoopStatus() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      setState(() => _whoopLinked = false);
      return;
    }
    final linkedHint = await AccountStorage.getWhoopLinked();
    if (linkedHint != null && mounted) {
      setState(() => _whoopLinked = linkedHint);
    }
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/whoop/status?user_id=$userId&backfill=0",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      final linked = data["linked"] == true;
      setState(() => _whoopLinked = linked);
      await AccountStorage.setWhoopLinked(linked);
    } catch (_) {
      if (!mounted) return;
      final fallback = await AccountStorage.getWhoopLinked();
      if (!mounted) return;
      if (fallback != null) {
        setState(() => _whoopLinked = fallback);
      }
    }
  }

  Future<void> _loadFitbitStatus() async {
    final linkedHint = await AccountStorage.getFitbitLinked();
    if (linkedHint != null && mounted) {
      setState(() => _fitbitLinked = linkedHint);
    }
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (mounted) setState(() => _fitbitLinked = false);
        return;
      }
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (linkedHint != null && mounted) {
          setState(() => _fitbitLinked = linkedHint);
        }
        return;
      }
      final data = json.decode(response.body);
      final linked = data["linked"] == true;
      if (!mounted) return;
      setState(() => _fitbitLinked = linked);
      await AccountStorage.setFitbitLinked(linked);
    } catch (_) {
      if (!mounted) return;
      final fallback = await AccountStorage.getFitbitLinked();
      if (!mounted) return;
      if (fallback != null) {
        setState(() => _fitbitLinked = fallback);
      }
    }
  }

  Future<void> _loadStravaStatus() async {
    final linkedHint = await AccountStorage.getStravaLinked();
    if (linkedHint != null && mounted) {
      setState(() => _stravaLinked = linkedHint);
    }
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (mounted) setState(() => _stravaLinked = false);
        return;
      }
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/strava/status?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (linkedHint != null && mounted) {
          setState(() => _stravaLinked = linkedHint);
        }
        return;
      }
      final data = json.decode(response.body);
      final linked = data["linked"] == true;
      if (!mounted) return;
      setState(() => _stravaLinked = linked);
      await AccountStorage.setStravaLinked(linked);
    } catch (_) {
      if (!mounted) return;
      final fallback = await AccountStorage.getStravaLinked();
      if (!mounted) return;
      if (fallback != null) {
        setState(() => _stravaLinked = fallback);
      }
    }
  }

  Future<void> _loadAppleWatchStatus({
    bool requestPermissionIfNeeded = false,
  }) async {
    if (!Platform.isIOS) {
      if (mounted) {
        setState(() {
          _appleWatchDetected = false;
          _wearableDetectedType = null;
        });
      }
      return;
    }

    final userId = await AccountStorage.getUserId();
    if (!mounted || userId == null || userId == 0) {
      if (mounted) {
        setState(() {
          _appleWatchDetected = null;
          _wearableDetectedType = null;
        });
      }
      return;
    }

    if (!requestPermissionIfNeeded) {
      final hint = await AccountStorage.getAppleWatchDetected();
      final hintType = await AccountStorage.getWearableDetectedType();
      if (mounted && hint != null) {
        setState(() {
          _appleWatchDetected = hint;
          _wearableDetectedType = hint ? hintType : null;
        });
      }
    }

    final previous = _appleWatchDetected;
    if (mounted) setState(() => _appleWatchChecking = true);
    try {
      final result = await AppleWatchDetectionService().detectAny(
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      );
      final detected = result.detected;
      final type = switch (result.kind) {
        WearableDetectionKind.apple => 'apple',
        WearableDetectionKind.other => 'other',
        WearableDetectionKind.none => null,
      };
      if (!mounted) return;
      setState(() {
        _appleWatchDetected = detected;
        _wearableDetectedType = type;
      });
      await AccountStorage.setAppleWatchDetected(detected);
      await AccountStorage.setWearableDetectedType(type);
      if (detected == true && previous != true) {
        AccountStorage.notifyAppleWatchChanged();
      }
    } finally {
      if (mounted) setState(() => _appleWatchChecking = false);
    }
  }

  Future<void> _handleAppleWatchTap() async {
    if (_appleWatchChecking || !Platform.isIOS || _isDeactivated) return;
    await _loadAppleWatchStatus(requestPermissionIfNeeded: true);
  }

  Future<void> _connectWhoop() async {
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(
        context,
        loc.translate("whoop_login_required"),
        type: AppToastType.info,
      );
      return;
    }
    setState(() => _whoopLoading = true);
    try {
      final token = await AccountStorage.getAccessToken();
      final t = token?.trim();
      if (t == null || t.isEmpty) {
        AppToast.show(
          context,
          loc.translate("please_login_again"),
          type: AppToastType.info,
        );
        return;
      }
      final url =
          "${ApiConfig.baseUrl}/auth/whoop/login?user_id=$userId&token=$t";
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'taqa',
      );
      final uri = Uri.tryParse(result);
      final ok = uri != null && uri.scheme == 'taqa' && uri.host == 'whoop';
      if (!mounted) return;
      setState(() => _whoopLinked = ok);
      if (ok) {
        await AccountStorage.setWhoopLinked(true);
        AccountStorage.notifyWhoopChanged();
        AccountStorage.notifyAccountChanged();
        try {
          await WhoopDailySync().forceBackfillRecent();
          await DailyProviderPushService().pushIfAfterOneAmLocal();
          WhoopLatestService.clear();
          AccountStorage.notifyWhoopChanged();
        } catch (_) {}
      }
      AppToast.show(
        context,
        ok
            ? loc.translate("whoop_connect_success")
            : loc.translate("whoop_connect_failed"),
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        loc
            .translate("whoop_connect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _whoopLoading = false);
    }
  }

  Future<void> _connectFitbit() async {
    if (_fitbitAuthInFlight) return;
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(
        context,
        loc.translate("fitbit_login_required"),
        type: AppToastType.info,
      );
      return;
    }
    _fitbitAuthInFlight = true;
    setState(() => _fitbitLoading = true);
    try {
      final token = await AccountStorage.getAccessToken();
      final t = token?.trim();
      if (t == null || t.isEmpty) {
        AppToast.show(
          context,
          loc.translate("please_login_again"),
          type: AppToastType.info,
        );
        return;
      }
      final url =
          "${ApiConfig.baseUrl}/auth/fitbit/login?user_id=$userId&token=$t";
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'taqa',
      );
      final uri = Uri.tryParse(result);
      final ok = uri != null && uri.scheme == 'taqa' && uri.host == 'fitbit';
      setState(() => _fitbitLinked = ok);
      if (ok) {
        await AccountStorage.setFitbitLinked(true);
      }
      if (ok) {
        AccountStorage.notifyAccountChanged();
      }
      AppToast.show(
        context,
        ok
            ? loc.translate("fitbit_connect_success")
            : loc.translate("fitbit_connect_failed"),
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        loc
            .translate("fitbit_connect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      _fitbitAuthInFlight = false;
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _connectStrava() async {
    if (_stravaAuthInFlight) return;
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(
        context,
        loc.translate("strava_login_required"),
        type: AppToastType.info,
      );
      return;
    }
    _stravaAuthInFlight = true;
    setState(() => _stravaLoading = true);
    try {
      final token = await AccountStorage.getAccessToken();
      final t = token?.trim();
      if (t == null || t.isEmpty) {
        AppToast.show(
          context,
          loc.translate("please_login_again"),
          type: AppToastType.info,
        );
        return;
      }
      final url =
          "${ApiConfig.baseUrl}/auth/strava/login?user_id=$userId&token=$t";
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'taqa',
      );
      final uri = Uri.tryParse(result);
      final ok = uri != null && uri.scheme == 'taqa' && uri.host == 'strava';
      setState(() => _stravaLinked = ok);
      if (ok) {
        await AccountStorage.setStravaLinked(true);
        AccountStorage.notifyAccountChanged();
      }
      AppToast.show(
        context,
        ok
            ? loc.translate("strava_connect_success")
            : loc.translate("strava_connect_failed"),
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        loc
            .translate("strava_connect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      _stravaAuthInFlight = false;
      if (mounted) setState(() => _stravaLoading = false);
    }
  }

  Future<void> _disconnectFitbit() async {
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final ok = await showTaqaConfirmDialog(
      context: context,
      title: loc.translate("fitbit_disconnect_title"),
      message: loc.translate("fitbit_disconnect_confirm"),
      confirmLabel: loc.translate("common_disconnect"),
    );
    if (!ok) return;
    setState(() => _fitbitLoading = true);
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/fitbit/disconnect?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      await http.post(url, headers: headers);
      setState(() => _fitbitLinked = false);
      await AccountStorage.setFitbitLinked(false);
      AccountStorage.notifyAccountChanged();
      AppToast.show(
        context,
        loc.translate("fitbit_disconnected"),
        type: AppToastType.success,
      );
    } catch (e) {
      AppToast.show(
        context,
        loc
            .translate("fitbit_disconnect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _disconnectStrava() async {
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final ok = await showTaqaConfirmDialog(
      context: context,
      title: loc.translate("strava_disconnect_title"),
      message: loc.translate("strava_disconnect_confirm"),
      confirmLabel: loc.translate("common_disconnect"),
    );
    if (!ok) return;
    setState(() => _stravaLoading = true);
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/strava/disconnect?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      await http.post(url, headers: headers);
      setState(() => _stravaLinked = false);
      await AccountStorage.setStravaLinked(false);
      AccountStorage.notifyAccountChanged();
      AppToast.show(
        context,
        loc.translate("strava_disconnected"),
        type: AppToastType.success,
      );
    } catch (e) {
      AppToast.show(
        context,
        loc
            .translate("strava_disconnect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _stravaLoading = false);
    }
  }

  Future<void> _handleFitbitTap() async {
    if (_fitbitLoading) return;
    if (_fitbitLinked) {
      await _disconnectFitbit();
    } else {
      await _connectFitbit();
    }
  }

  Future<void> _handleStravaTap() async {
    if (_stravaLoading) return;
    if (_stravaLinked) {
      await _disconnectStrava();
    } else {
      await _connectStrava();
    }
  }

  Future<void> _disconnectWhoop() async {
    final loc = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(
        context,
        loc.translate("please_login"),
        type: AppToastType.info,
      );
      return;
    }
    final ok = await showTaqaConfirmDialog(
      context: context,
      title: loc.translate("whoop_disconnect_title"),
      message: loc.translate("whoop_disconnect_confirm"),
      confirmLabel: loc.translate("common_disconnect"),
    );
    if (!ok) return;
    setState(() => _whoopLoading = true);
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/whoop/disconnect?user_id=$userId",
      );
      final headers = await AccountStorage.getAuthHeaders();
      final res = await http
          .post(url, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      if (!mounted) return;
      setState(() => _whoopLinked = false);
      await AccountStorage.setWhoopLinked(false);
      AccountStorage.notifyWhoopChanged();
      AccountStorage.notifyAccountChanged();
      AppToast.show(
        context,
        loc.translate("whoop_disconnected"),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        loc
            .translate("common_disconnect_failed_detail")
            .replaceAll("{error}", "$e"),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _whoopLoading = false);
    }
  }

  Future<void> _handleWhoopTap() async {
    if (_whoopLoading) return;
    if (_whoopLinked) {
      await _disconnectWhoop();
    } else {
      await _connectWhoop();
    }
  }

  Future<void> _pickAvatar() async {
    if (_updatingAvatar) return;
    final picker = ImagePicker();

    // Request camera/photos permissions so the picker works smoothly
    final granted = await ConsentManager.requestCameraOrGalleryForAvatar();
    if (!granted) {
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).translate("permissions_required"),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => _updatingAvatar = true);
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _updatingAvatar = false);
        return;
      }
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        if (!mounted) return;
        AppToast.show(
          context,
          AppLocalizations.of(context).translate("user_missing"),
          type: AppToastType.error,
        );
        return;
      }
      final url = await ProfileApi.uploadAvatar(userId, picked.path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final cacheBusted = url.contains("?") ? "$url&v=$stamp" : "$url?v=$stamp";
      try {
        final dir = await getApplicationDocumentsDirectory();
        final ext = picked.path.split('.').last;
        final localPath = "${dir.path}/avatar_${userId}_$stamp.$ext";
        final saved = await File(picked.path).copy(localPath);
        await AccountStorage.setAvatarPath(saved.path, userId: userId);
      } catch (_) {
        // Fallback to picker path if copy fails
        await AccountStorage.setAvatarPath(picked.path, userId: userId);
      }
      await AccountStorage.setAvatarUrl(cacheBusted, userId: userId);
      AccountStorage.notifyAccountChanged();
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).translate("avatar_updated"),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not update avatar. Please try again.',
        ),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _showSupportDialog({
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    await showTaqaInfoDialog(
      context: context,
      title: title,
      message: body,
      confirmLabel: AppLocalizations.of(context).translate("ok"),
    );
  }

  Future<void> _promptChangeUsername() async {
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    String currentUsername = "";
    if (userId != null && userId > 0) {
      try {
        final profile = await ProfileApi.fetchProfile(userId);
        currentUsername = (profile["username"] ?? "").toString().trim();
      } catch (_) {
        // Fallback to cached display name if profile request fails.
      }
    }
    if (currentUsername.isEmpty) {
      final cachedName = (await AccountStorage.getName() ?? "").trim();
      if (_usernameRegex.hasMatch(cachedName)) {
        currentUsername = cachedName;
      }
    }
    if (!mounted) return;

    final newUsername = await showTaqaTextValueDialog(
      context: context,
      title: t.translate("settings_change_username"),
      initialValue: currentUsername,
      keyboardType: TextInputType.text,
    );
    if (newUsername == null) return;
    final normalizedUsername = newUsername.trim();

    if (normalizedUsername.length < 3) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("signup_username_short"),
        type: AppToastType.error,
      );
      return;
    }
    if (normalizedUsername.length > 50) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("signup_username_long"),
        type: AppToastType.error,
      );
      return;
    }
    if (!_usernameRegex.hasMatch(normalizedUsername)) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("signup_username_invalid"),
        type: AppToastType.error,
      );
      return;
    }
    if (normalizedUsername.isEmpty || normalizedUsername == currentUsername) {
      return;
    }

    try {
      final uid = await AccountStorage.getUserId();
      if (uid == null) {
        if (!mounted) return;
        AppToast.show(
          context,
          t.translate("user_missing"),
          type: AppToastType.error,
        );
        return;
      }
      final updated = await ProfileApi.updateUsername(uid, normalizedUsername);
      await AccountStorage.setName(updated);
      if (!mounted) return;
      await _showSuccessDialog("${t.translate("username_updated")}: $updated");
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("user_missing"),
        type: AppToastType.error,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: AppColors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                t.translate("settings_delete_account"),
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                t.translate("settings_delete_account_confirm_body"),
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.translate("cancel")),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    t.translate("settings_delete_account_confirm_yes"),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await ProfileApi.deleteAccount(userId);
      await AccountStorage.clear();
      await NotificationService.refreshDailyJournalRemindersForCurrentUser();
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("settings_delete_account_success"),
        type: AppToastType.success,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not delete account. Please try again.',
        ),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _confirmDeactivateAccount() async {
    if (_deactivatingAccount) return;
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("user_missing"),
        type: AppToastType.error,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: AppColors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                t.translate("settings_deactivate_account"),
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                t.translate("settings_deactivate_account_confirm_body"),
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.translate("cancel")),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    t.translate("settings_deactivate_account_confirm_yes"),
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _deactivatingAccount = true);
    try {
      final result = await ProfileApi.deactivateAccount(userId);
      if (!mounted) return;
      setState(() {
        _isDeactivated = true;
        _scheduledPurgeAtDisplay = _normalizeDate(
          result["scheduled_purge_at"]?.toString(),
        );
      });
      AppToast.show(
        context,
        (result["message"]?.toString().trim().isNotEmpty ?? false)
            ? result["message"].toString()
            : t.translate("settings_deactivate_account_success"),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not deactivate account. Please try again.',
        ),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deactivatingAccount = false);
    }
  }

  Future<void> _openReactivationFlow() async {
    final payload = <String, dynamic>{
      "status": "deactivated",
      if (_scheduledPurgeAtDisplay != null)
        "scheduled_purge_at": _scheduledPurgeAtDisplay,
    };
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AccountRestorePage(initialPayload: payload, prefilledEmail: _email),
      ),
    );
    await _refreshAccountStatus();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TaqaUiScale.insetsLTRB(16, 12, 16, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    t.translate("settings"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward_ios
                            : Icons.arrow_back_ios_new,
                        size: TaqaUiScale.w(18),
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 24),
                children: [
                  _sectionTitle(t.translate("settings_language")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  Row(
                    children: [
                      Expanded(
                        child: TaqaRangeTab(
                          label: "English",
                          selected: _langCode == "en",
                          onTap: () => _changeLanguage(const Locale('en')),
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(15)),
                      Expanded(
                        child: TaqaRangeTab(
                          label: "Arabic",
                          selected: _langCode == "ar",
                          onTap: () => _changeLanguage(const Locale('ar')),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  if (_isDeactivated) ...[
                    Container(
                      width: double.infinity,
                      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
                      margin: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: TaqaUiScale.radius(15),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _scheduledPurgeAtDisplay == null
                            ? t.translate("deactivated_banner_no_date")
                            : t
                                  .translate("deactivated_banner_with_date")
                                  .replaceAll(
                                    "{date}",
                                    _scheduledPurgeAtDisplay!,
                                  ),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w400,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ],
                  _sectionTitle(t.translate("settings_profile")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _SettingsTile(
                    title: t.translate("settings_change_username"),
                    subtitle: t.translate("settings_change_username_sub"),
                    onTap: _isDeactivated ? null : _promptChangeUsername,
                  ),
                  _SettingsTile(
                    title: t.translate("settings_change_avatar"),
                    subtitle: t.translate("settings_change_avatar_sub"),
                    onTap: _isDeactivated ? null : _pickAvatar,
                  ),
                  if (_showBeExpertButton)
                    _SettingsTile(
                      title: t.translate("settings_be_expert"),
                      subtitle: t.translate("settings_be_expert_sub"),
                      onTap: _isDeactivated
                          ? null
                          : () async {
                              final userId = await AccountStorage.getUserId();
                              if (userId == null) {
                                AppToast.show(
                                  context,
                                  t.translate("user_missing"),
                                  type: AppToastType.error,
                                );
                                return;
                              }
                              try {
                                final lang = AppLocalizations.of(
                                  context,
                                ).locale.languageCode;
                                final profile = await ProfileApi.fetchProfile(
                                  userId,
                                  lang: lang,
                                );
                                final done =
                                    profile["filled_expert_questionnaire"] ==
                                    true;
                                if (done) {
                                  AppToast.show(
                                    context,
                                    t.translate(
                                      "expert_questionnaire_already_done",
                                    ),
                                    type: AppToastType.info,
                                  );
                                  return;
                                }
                              } catch (_) {
                                // If check fails, allow navigation so user can try
                              }
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ExpertQuestionnairePage(),
                                ),
                              );
                              await _loadExpertFlag();
                            },
                    ),
                  if (_isExpert) ...[
                    const SizedBox(height: 12),
                    _sectionTitle(t.translate("settings_coach")),
                    SizedBox(height: TaqaUiScale.h(12)),
                    const _CoachPinTile(),
                    SizedBox(height: TaqaUiScale.h(12)),
                    const _HabitReminderCard(),
                  ],
                  const SizedBox(height: 12),
                  _sectionTitle(t.translate("settings_security")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  if (_authProvider != "google" && _authProvider != "apple")
                    _SettingsTile(
                      title: t.translate("settings_change_password"),
                      subtitle: t.translate("settings_change_password_sub"),
                      onTap: _isDeactivated
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordPage(
                                    lockedEmail: _email,
                                    lockEmailField: _email != null,
                                  ),
                                ),
                              );
                            },
                    ),
                  if (_isDeactivated)
                    _SettingsTile(
                      title: t.translate("account_reactivate_action"),
                      subtitle: t.translate("settings_reactivate_account_sub"),
                      onTap: _openReactivationFlow,
                    ),
                  if (!_isDeactivated)
                    _SettingsTile(
                      title: t.translate("settings_deactivate_account"),
                      subtitle: t.translate("settings_deactivate_account_sub"),
                      onTap: _deactivatingAccount
                          ? null
                          : _confirmDeactivateAccount,
                    ),
                  _SettingsTile(
                    title: t.translate("settings_delete_account"),
                    subtitle: t.translate("settings_delete_account_sub"),
                    onTap: _deletingAccount ? null : _confirmDeleteAccount,
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  _sectionTitle(t.translate("settings_devices")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _SettingsTile(
                    title: _whoopLinked
                        ? t.translate("whoop_connected_title")
                        : t.translate("whoop_connect_title"),
                    subtitle: _whoopLinked
                        ? t.translate("whoop_disconnect_subtitle")
                        : t.translate("whoop_link_subtitle"),
                    onTap: (_whoopLoading || _isDeactivated)
                        ? null
                        : _handleWhoopTap,
                    badge: Image.asset(
                      'assets/images/whoop.png',
                      height: TaqaUiScale.h(18),
                      fit: BoxFit.contain,
                    ),
                  ),
                  _SettingsTile(
                    title: _fitbitLinked
                        ? t.translate("fitbit_connected_title")
                        : t.translate("fitbit_connect_title"),
                    subtitle: _fitbitLinked
                        ? t.translate("fitbit_disconnect_subtitle")
                        : t.translate("fitbit_link_subtitle"),
                    onTap: (_fitbitLoading || _isDeactivated)
                        ? null
                        : _handleFitbitTap,
                    badge: Image.asset(
                      'assets/images/fitbit.png',
                      height: TaqaUiScale.h(14),
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Strava and wearable detection are disabled until further notice.
                  /*
                  _SettingsTile(
                    title: _stravaLinked
                        ? t.translate("strava_connected_title")
                        : t.translate("strava_connect_title"),
                    subtitle: _stravaLinked
                        ? t.translate("strava_disconnect_subtitle")
                        : t.translate("strava_link_subtitle"),
                    onTap: (_stravaLoading || _isDeactivated)
                        ? null
                        : _handleStravaTap,
                    badge: Image.asset(
                      'assets/images/strava_logo_icon_170697.png',
                      height: TaqaUiScale.h(18),
                      fit: BoxFit.contain,
                    ),
                  ),
                  _SettingsTile(
                    title: !Platform.isIOS
                        ? t.translate("wearable_unavailable_title")
                        : _appleWatchChecking
                        ? t.translate("wearable_checking_title")
                        : (_appleWatchDetected == true
                              ? (_wearableDetectedType == 'apple'
                                    ? t.translate("apple_watch_detected_title")
                                    : t.translate("wearable_detected_title"))
                              : t.translate("wearable_not_detected_title")),
                    subtitle: !Platform.isIOS
                        ? t.translate("wearable_ios_only_subtitle")
                        : (_appleWatchDetected == true
                              ? (_wearableDetectedType == 'apple'
                                    ? t.translate("apple_watch_health_data_subtitle")
                                    : t.translate("wearable_health_data_subtitle"))
                              : t.translate("wearable_no_source_subtitle")),
                    onTap:
                        (!Platform.isIOS ||
                            _isDeactivated ||
                            _appleWatchChecking)
                        ? null
                        : _handleAppleWatchTap,
                    badge: Container(
                      height: TaqaUiScale.h(20),
                      width: TaqaUiScale.w(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A7A7A),
                        borderRadius: TaqaUiScale.radius(6),
                      ),
                      child: Icon(
                        Icons.watch,
                        color: TaqaUiColors.white,
                        size: TaqaUiScale.w(12),
                      ),
                    ),
                  ),
                  */
                  SizedBox(height: TaqaUiScale.h(24)),
                  _sectionTitle(t.translate("settings_support")),
                  SizedBox(height: TaqaUiScale.h(12)),
                  _SettingsTile(
                    title: t.translate("settings_contact"),
                    subtitle: t.translate("settings_contact_sub"),
                    onTap: () => _showSupportDialog(
                      title: t.translate("settings_contact"),
                      body: t.translate("settings_contact_body"),
                    ),
                  ),
                  _SettingsTile(
                    title: t.translate("settings_help"),
                    subtitle: t.translate("settings_help_sub"),
                    onTap: () => _showSupportDialog(
                      title: t.translate("settings_help"),
                      body: t.translate("settings_help_body"),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        fontSize: TaqaUiScale.sp(15),
        fontWeight: FontWeight.w700,
        height: 25 / 15,
        letterSpacing: 0,
        color: TaqaUiColors.unnamedColor1c1d17,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(15),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiScale.radius(15),
            border: Border.all(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
            ),
          ),
          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: badge == null
                        ? EdgeInsets.zero
                        : EdgeInsets.only(right: TaqaUiScale.w(36)),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        height: 25 / 15,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w400,
                      height: 18 / 13,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              if (badge != null) Positioned(top: 0, right: 0, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachPinTile extends StatefulWidget {
  const _CoachPinTile();

  @override
  State<_CoachPinTile> createState() => _CoachPinTileState();
}

class _CoachPinTileState extends State<_CoachPinTile> {
  // Cached across the app's lifetime so re-opening Settings doesn't refetch
  // the coach PIN every time — it never changes during a session.
  static String? _cachedPin;
  static bool _pinCached = false;

  bool _loading = !_pinCached;
  String? _pin = _cachedPin;

  @override
  void initState() {
    super.initState();
    if (!_pinCached) _load();
  }

  Future<void> _load() async {
    try {
      final pin = await ProgressionReviewService.fetchMyCoachCode();
      _cachedPin = pin;
      _pinCached = true;
      if (!mounted) return;
      setState(() {
        _pin = pin;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final pin = (_pin ?? '').trim();
    if (pin.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pin));
    if (!mounted) return;
    AppToast.show(context, 'Coach PIN copied', type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final pin = (_pin ?? '').trim();
    return TaqaLogEntryCard(
      title: 'Coach PIN',
      badgeText: '',
      badge: pin.isEmpty
          ? null
          : TaqaOutlineTagButton(
              label: 'Copy',
              width: TaqaUiScale.w(29),
              height: TaqaUiScale.h(16),
            ),
      subtitle: _loading
          ? 'Loading...'
          : pin.isEmpty
          ? 'Coach PIN unavailable.'
          : pin,
      onTap: pin.isEmpty ? null : _copy,
    );
  }
}

class _HabitReminderCard extends StatefulWidget {
  const _HabitReminderCard();

  @override
  State<_HabitReminderCard> createState() => _HabitReminderCardState();
}

class _HabitReminderCardState extends State<_HabitReminderCard> {
  static const _weekdayOptions = <MapEntry<int, String>>[
    MapEntry<int, String>(0, 'Monday'),
    MapEntry<int, String>(1, 'Tuesday'),
    MapEntry<int, String>(2, 'Wednesday'),
    MapEntry<int, String>(3, 'Thursday'),
    MapEntry<int, String>(4, 'Friday'),
    MapEntry<int, String>(5, 'Saturday'),
    MapEntry<int, String>(6, 'Sunday'),
  ];

  // Cached across the app's lifetime so re-opening Settings doesn't refetch
  // on every visit — only a successful save invalidates/refreshes it.
  static CoachHabitReminderSettings? _cachedSettings;
  static bool _settingsCached = false;

  bool _loading = false;
  bool _saving = false;
  bool _triggering = false;
  bool _loaded = false;
  bool _autoEnabled = false;
  String _scheduleType = 'weekly';
  int _weeklyDay = 0;
  int _hourOfDay = 9;
  String _timeZone = 'UTC';

  @override
  void initState() {
    super.initState();
    if (_settingsCached && _cachedSettings != null) {
      _applySettings(_cachedSettings!);
    } else {
      _load();
    }
  }

  void _applySettings(CoachHabitReminderSettings settings) {
    _autoEnabled = settings.autoEnabled;
    final schedule = (settings.scheduleType ?? '').trim().toLowerCase();
    _scheduleType = schedule == 'daily' ? 'daily' : 'weekly';
    _weeklyDay = settings.weeklyDay.clamp(0, 6);
    _hourOfDay = settings.hourOfDay.clamp(0, 23);
    _timeZone = settings.timeZone.trim().isEmpty
        ? 'UTC'
        : settings.timeZone.trim();
    _loaded = true;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await CoachHabitReminderSettingsService.fetchSettings();
      _cachedSettings = settings;
      _settingsCached = true;
      if (!mounted) return;
      setState(() => _applySettings(settings));
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await CoachHabitReminderSettingsService.updateSettings(
        autoEnabled: _autoEnabled,
        scheduleType: _scheduleType,
        weeklyDay: _weeklyDay,
        hourOfDay: _hourOfDay,
      );
      _cachedSettings = updated;
      _settingsCached = true;
      if (!mounted) return;
      setState(() => _applySettings(updated));
      AppToast.show(
        context,
        'Habit reminder settings saved.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _triggerNow() async {
    if (_triggering) return;
    setState(() => _triggering = true);
    try {
      final result = await CoachHabitReminderSettingsService.triggerNow();
      if (!mounted) return;
      final triggered = (result['triggered_clients'] as num?)?.toInt() ?? 0;
      final targeted = (result['targeted_clients'] as num?)?.toInt() ?? 0;
      AppToast.show(
        context,
        triggered > 0
            ? 'Triggered reminders for $triggered of $targeted clients.'
            : 'No reminder was triggered right now.',
        type: triggered > 0 ? AppToastType.success : AppToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  Future<void> _pickWeekday(BuildContext context) async {
    final selectedLabel = _weekdayOptions
        .firstWhere((e) => e.key == _weeklyDay)
        .value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TaqaCommunityOptionPickerSheet(
        title: 'Day of week',
        options: _weekdayOptions.map((e) => e.value).toList(growable: false),
        selectedValue: selectedLabel,
        onSelected: (value) {
          final entry = _weekdayOptions.firstWhere((e) => e.value == value);
          setState(() => _weeklyDay = entry.key);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static String _hourLabel(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }

  Future<void> _pickHour(BuildContext context) async {
    final hourOptions = List<int>.generate(24, (index) => index);
    final selectedLabel = _hourLabel(_hourOfDay);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TaqaCommunityOptionPickerSheet(
        title: 'Hour',
        options: hourOptions.map(_hourLabel).toList(growable: false),
        selectedValue: selectedLabel,
        onSelected: (value) {
          final hour = hourOptions.firstWhere(
            (h) => _hourLabel(h) == value,
          );
          setState(() => _hourOfDay = hour);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlsDisabled = _loading || _saving;
    final scheduleSubtitle = _scheduleType == 'weekly'
        ? 'Choose one weekday and one hour.'
        : 'Choose one hour for daily trigger.';
    final labelColor = TaqaUiColors.unnamedColor1c1d17;

    return Container(
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
        ),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habit Reminder Automation',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              height: 25 / 15,
              letterSpacing: 0,
              color: labelColor,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(6)),
          Text(
            'Automatic reminder scheduling for all assigned clients. Server time: $_timeZone',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
              letterSpacing: 0,
              color: labelColor,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Auto send habit reminders to all clients',
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(13),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: labelColor,
                  ),
                ),
              ),
              TaqaSwitch(
                value: _autoEnabled,
                onChanged: controlsDisabled
                    ? null
                    : (value) => setState(() => _autoEnabled = value),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              Expanded(
                child: TaqaSegmentedToggleButton(
                  label: 'WEEKLY',
                  selected: _scheduleType == 'weekly',
                  onTap: !_autoEnabled || controlsDisabled
                      ? null
                      : () => setState(() => _scheduleType = 'weekly'),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: TaqaSegmentedToggleButton(
                  label: 'DAILY',
                  selected: _scheduleType == 'daily',
                  onTap: !_autoEnabled || controlsDisabled
                      ? null
                      : () => setState(() => _scheduleType = 'daily'),
                ),
              ),
            ],
          ),
          if (_autoEnabled) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            Text(
              scheduleSubtitle,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                letterSpacing: 0,
                color: labelColor.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(10)),
            if (_scheduleType == 'weekly') ...[
              _SelectField(
                label: 'Day of week',
                valueLabel: _weekdayOptions
                    .firstWhere((e) => e.key == _weeklyDay)
                    .value,
                onTap: controlsDisabled
                    ? null
                    : () => _pickWeekday(context),
              ),
              SizedBox(height: TaqaUiScale.h(10)),
            ],
            _SelectField(
              label: 'Hour',
              valueLabel: _hourLabel(_hourOfDay),
              onTap: controlsDisabled ? null : () => _pickHour(context),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(14)),
          TaqaFilledButton(
            label: 'Save auto reminder settings',
            onTap: controlsDisabled ? null : _save,
            loading: _saving,
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(
            label: 'Send habit reminders now',
            onTap: _triggering ? null : _triggerNow,
            loading: _triggering,
          ),
          if (_loading && !_loaded) ...[
            SizedBox(height: TaqaUiScale.h(10)),
            Text(
              'Loading reminder settings...',
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(12),
                color: labelColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.valueLabel,
    required this.onTap,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TaqaUiScale.radius(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: TaqaUiScale.radius(10),
        ),
        padding: TaqaUiScale.insetsLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(11),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(2)),
                  Text(
                    valueLabel,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: TaqaUiScale.w(18),
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
