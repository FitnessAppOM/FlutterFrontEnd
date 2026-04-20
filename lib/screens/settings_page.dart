import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../widgets/lang_button.dart';
import '../core/locale_controller.dart';
import 'ForgetPassword/forgot_password_page.dart';
import '../services/auth/profile_service.dart';
import '../core/account_storage.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../config/base_url.dart';
import '../consents/consent_manager.dart';
import '../auth/expert_questionnaire.dart';
import '../services/core/daily_provider_push_service.dart';
import '../services/core/notification_service.dart';
import '../services/health/apple_watch_detection_service.dart';
import '../services/whoop/whoop_daily_sync.dart';
import '../services/whoop/whoop_latest_service.dart';
import '../services/auth/profile_storage.dart';
import '../screens/welcome.dart';
import '../screens/account_restore_page.dart';
import '../screens/coach_page.dart';
import '../screens/expert_dashboard_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _usernameController = TextEditingController();
  final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9._-]+$');
  bool _updatingUsername = false;
  bool _updatingAvatar = false;
  bool _deletingAccount = false;
  bool _deactivatingAccount = false;
  bool _isDeactivated = false;
  bool _isExpert = false;
  bool _expertFlagReady = false;
  String? _expertProfileStatus;
  String? _scheduledPurgeAtDisplay;
  String? _email;
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
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.accent, size: 42),
              const SizedBox(height: 12),
              Text(
                t.translate("settings"),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.translate("ok")),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJwtTokenDialog() async {
    final token = await AccountStorage.getAccessToken();
    if (!mounted) return;
    final display = (token == null || token.trim().isEmpty)
        ? "No JWT token found. Please log in again."
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
                const Text(
                  "JWT Token",
                  style: TextStyle(
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
                        child: const Text("Close"),
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
                                  "Token copied",
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
    _usernameController.dispose();
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

  Future<void> _loadExpertFlag() async {
    if (mounted) {
      setState(() => _expertFlagReady = false);
    }
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
      final cachedHasExpertProfile =
          cachedProfile?["has_expert_profile"] == true;
      final cachedFilledExpert =
          cachedProfile?["filled_expert_questionnaire"] == true;
      done = done || cachedFilledExpert;
      isExpert =
          isExpert ||
          cachedHasExpertProfile ||
          cachedFilledExpert ||
          rawCached == "approved" ||
          rawCached == "pending";
    } catch (_) {
      // Ignore cache parse failures.
    }

    final userId = await AccountStorage.getUserId();
    if (userId != null && userId > 0) {
      try {
        if (!mounted) return;
        final lang = AppLocalizations.of(context).locale.languageCode;
        final profile = await ProfileApi.fetchProfile(userId, lang: lang);
        final hasExpertProfile = profile["has_expert_profile"] == true;
        final filledExpertQuestionnaire =
            profile["filled_expert_questionnaire"] == true;
        final rawStatus = (profile["expert_profile_status"] ?? "")
            .toString()
            .trim()
            .toLowerCase();
        expertProfileStatus = rawStatus.isEmpty ? null : rawStatus;
        done = done || filledExpertQuestionnaire;
        isExpert =
            isExpert ||
            hasExpertProfile ||
            filledExpertQuestionnaire ||
            rawStatus == "approved" ||
            rawStatus == "pending";
        await AccountStorage.setExpertQuestionnaireDone(done);
        await AccountStorage.setIsExpert(isExpert);
      } catch (_) {
        // Keep existing fallback behavior when profile API isn't reachable.
      }
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

  Future<bool> _resolveExpertPortalAccess() async {
    await _loadExpertFlag();
    return AccountStorage.isExpert();
  }

  Future<void> _openCoachPortal() async {
    final isExpert = await _resolveExpertPortalAccess();
    if (!mounted) return;

    if (!isExpert) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CoachPage()));
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            'Open coach portal',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Expert Dashboard',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Approve and apply recommendations',
                  style: TextStyle(color: Colors.white60),
                ),
                onTap: () => Navigator.of(context).pop('expert'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.record_voice_over,
                  color: Colors.white,
                ),
                title: const Text(
                  'Client Coach Page',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Open feedback/chat/form-check view',
                  style: TextStyle(color: Colors.white60),
                ),
                onTap: () => Navigator.of(context).pop('client'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (!mounted || choice == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => choice == 'expert'
            ? const ExpertDashboardPage()
            : const CoachPage(),
      ),
    );
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
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(
        context,
        "Please log in to connect Whoop.",
        type: AppToastType.info,
      );
      return;
    }
    setState(() => _whoopLoading = true);
    try {
      final token = await AccountStorage.getAccessToken();
      final t = token?.trim();
      if (t == null || t.isEmpty) {
        AppToast.show(context, "Please log in again.", type: AppToastType.info);
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
        ok ? "Whoop connected successfully." : "Whoop connect failed.",
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        "Whoop connect failed: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _whoopLoading = false);
    }
  }

  Future<void> _connectFitbit() async {
    if (_fitbitAuthInFlight) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(
        context,
        "Please log in to connect Fitbit.",
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
        AppToast.show(context, "Please log in again.", type: AppToastType.info);
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
        ok ? "Fitbit connected successfully." : "Fitbit connect failed.",
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        "Fitbit connect failed: $e",
        type: AppToastType.error,
      );
    } finally {
      _fitbitAuthInFlight = false;
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _connectStrava() async {
    if (_stravaAuthInFlight) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(
        context,
        "Please log in to connect Strava.",
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
        AppToast.show(context, "Please log in again.", type: AppToastType.info);
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
        ok ? "Strava connected successfully." : "Strava connect failed.",
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (_isAuthCancelled(e)) {
        return;
      }
      AppToast.show(
        context,
        "Strava connect failed: $e",
        type: AppToastType.error,
      );
    } finally {
      _stravaAuthInFlight = false;
      if (mounted) setState(() => _stravaLoading = false);
    }
  }

  Future<void> _disconnectFitbit() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final ok = await showConfirmDialog(
      context: context,
      title: "Disconnect Fitbit",
      message: "Are you sure you want to disconnect Fitbit?",
      confirmText: "Disconnect",
    );
    if (ok != true) return;
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
        "Fitbit disconnected.",
        type: AppToastType.success,
      );
    } catch (e) {
      AppToast.show(
        context,
        "Fitbit disconnect failed: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _disconnectStrava() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return;
    final ok = await showConfirmDialog(
      context: context,
      title: "Disconnect Strava",
      message: "Are you sure you want to disconnect Strava?",
      confirmText: "Disconnect",
    );
    if (ok != true) return;
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
        "Strava disconnected.",
        type: AppToastType.success,
      );
    } catch (e) {
      AppToast.show(
        context,
        "Strava disconnect failed: $e",
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
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(context, "Please log in.", type: AppToastType.info);
      return;
    }
    final ok = await showConfirmDialog(
      context: context,
      title: "Disconnect Whoop",
      message: "Are you sure you want to disconnect Whoop?",
      confirmText: "Disconnect",
    );
    if (ok != true) return;
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
      AppToast.show(context, "Whoop disconnected.", type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, "Disconnect failed: $e", type: AppToastType.error);
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
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _showSupportDialog({
    required String title,
    required String body,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(body, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).translate("ok")),
            ),
          ],
        );
      },
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
      currentUsername = (await AccountStorage.getName() ?? "").trim();
    }
    _usernameController.text = currentUsername;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.black,
          title: Text(
            t.translate("settings_change_username"),
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: t.translate("settings_change_username"),
              hintText: "yourname_123",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.translate("cancel")),
            ),
            TextButton(
              onPressed: _updatingUsername
                  ? null
                  : () async {
                      final newUsername = _usernameController.text.trim();
                      if (newUsername.length < 3) {
                        AppToast.show(
                          context,
                          t.translate("signup_username_short"),
                          type: AppToastType.error,
                        );
                        return;
                      }
                      if (newUsername.length > 50) {
                        AppToast.show(
                          context,
                          t.translate("signup_username_long"),
                          type: AppToastType.error,
                        );
                        return;
                      }
                      if (!_usernameRegex.hasMatch(newUsername)) {
                        AppToast.show(
                          context,
                          t.translate("signup_username_invalid"),
                          type: AppToastType.error,
                        );
                        return;
                      }
                      if (newUsername.isEmpty ||
                          newUsername == currentUsername) {
                        Navigator.pop(ctx);
                        return;
                      }
                      setState(() => _updatingUsername = true);
                      try {
                        final uid = await AccountStorage.getUserId();
                        if (uid == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.translate("user_missing")),
                            ),
                          );
                          setState(() => _updatingUsername = false);
                          return;
                        }
                        final updated = await ProfileApi.updateUsername(
                          uid,
                          newUsername,
                        );
                        await AccountStorage.setName(updated);
                        await _showSuccessDialog(
                          "${t.translate("username_updated")}: $updated",
                        );
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                      } catch (e) {
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          e.toString(),
                          type: AppToastType.error,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _updatingUsername = false);
                        }
                      }
                    },
              child: _updatingUsername
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.translate("save")),
            ),
          ],
        );
      },
    );
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
      AppToast.show(context, e.toString(), type: AppToastType.error);
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
      AppToast.show(context, e.toString(), type: AppToastType.error);
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
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("settings")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t.translate("settings_language"),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LangButton(
                label: "EN",
                flag: "🇬🇧",
                selected: _langCode == "en",
                onTap: () => _changeLanguage(const Locale('en')),
              ),
              LangButton(
                label: "AR",
                flag: "🇸🇦",
                selected: _langCode == "ar",
                onTap: () => _changeLanguage(const Locale('ar')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isDeactivated) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _scheduledPurgeAtDisplay == null
                    ? t.translate("deactivated_banner_no_date")
                    : t
                          .translate("deactivated_banner_with_date")
                          .replaceAll("{date}", _scheduledPurgeAtDisplay!),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
          Text(
            t.translate("settings_profile"),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: t.translate("settings_change_username"),
            subtitle: t.translate("settings_change_username_sub"),
            icon: Icons.person_outline,
            onTap: _isDeactivated ? null : _promptChangeUsername,
          ),
          _SettingsTile(
            title: t.translate("settings_change_avatar"),
            subtitle: t.translate("settings_change_avatar_sub"),
            icon: _updatingAvatar
                ? Icons.hourglass_bottom
                : Icons.image_outlined,
            onTap: _isDeactivated ? null : _pickAvatar,
          ),
          if (_showBeExpertButton)
            _SettingsTile(
              title: t.translate("settings_be_expert"),
              subtitle: t.translate("settings_be_expert_sub"),
              icon: Icons.work_outline,
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
                            profile["filled_expert_questionnaire"] == true;
                        if (done) {
                          AppToast.show(
                            context,
                            t.translate("expert_questionnaire_already_done"),
                            type: AppToastType.info,
                          );
                          return;
                        }
                      } catch (_) {
                        // If check fails, allow navigation so user can try
                      }
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExpertQuestionnairePage(),
                        ),
                      );
                      await _loadExpertFlag();
                    },
            ),
          _SettingsTile(
            title: t.translate("settings_coach_portal"),
            subtitle: _isExpert
                ? t.translate("settings_coach_portal_sub_expert")
                : t.translate("settings_coach_portal_sub_client"),
            icon: _isExpert
                ? Icons.analytics_outlined
                : Icons.record_voice_over,
            onTap: _isDeactivated ? null : _openCoachPortal,
          ),
          const SizedBox(height: 12),
          Text(
            t.translate("settings_security"),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: t.translate("settings_change_password"),
            subtitle: t.translate("settings_change_password_sub"),
            icon: Icons.lock_reset,
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
              icon: Icons.refresh,
              onTap: _openReactivationFlow,
              color: AppColors.accent,
            ),
          if (!_isDeactivated)
            _SettingsTile(
              title: t.translate("settings_deactivate_account"),
              subtitle: t.translate("settings_deactivate_account_sub"),
              icon: _deactivatingAccount
                  ? Icons.hourglass_bottom
                  : Icons.pause_circle_outline,
              onTap: _deactivatingAccount ? null : _confirmDeactivateAccount,
              color: Colors.amberAccent,
            ),
          _SettingsTile(
            title: t.translate("settings_delete_account"),
            subtitle: t.translate("settings_delete_account_sub"),
            icon: _deletingAccount
                ? Icons.hourglass_bottom
                : Icons.delete_forever,
            onTap: _deletingAccount ? null : _confirmDeleteAccount,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 24),
          Text(
            "Devices",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: _whoopLinked ? "Whoop connected" : "Connect Whoop",
            subtitle: _whoopLinked
                ? "Disconnect your Whoop"
                : "Link your Whoop account",
            icon: _whoopLoading ? Icons.hourglass_bottom : Icons.monitor_heart,
            onTap: (_whoopLoading || _isDeactivated) ? null : _handleWhoopTap,
            color: _whoopLinked ? const Color(0xFF4CD964) : null,
            leading: SizedBox(
              height: 28,
              width: 28,
              child: Center(
                child: Image.asset(
                  'assets/images/whoop.png',
                  height: 18,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          _SettingsTile(
            title: _fitbitLinked ? "Fitbit connected" : "Connect Fitbit",
            subtitle: _fitbitLinked
                ? "Disconnect your Fitbit"
                : "Link your Fitbit account",
            icon: _fitbitLoading
                ? Icons.hourglass_bottom
                : Icons.directions_walk,
            onTap: (_fitbitLoading || _isDeactivated) ? null : _handleFitbitTap,
            color: _fitbitLinked ? const Color(0xFF4CD964) : null,
            leading: SizedBox(
              height: 28,
              width: 28,
              child: Center(
                child: Image.asset(
                  'assets/images/fitbit.png',
                  height: 14,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          _SettingsTile(
            title: _stravaLinked ? "Strava connected" : "Connect Strava",
            subtitle: _stravaLinked
                ? "Disconnect your Strava"
                : "Link your Strava account",
            icon: _stravaLoading
                ? Icons.hourglass_bottom
                : Icons.directions_bike,
            onTap: (_stravaLoading || _isDeactivated) ? null : _handleStravaTap,
            color: _stravaLinked ? const Color(0xFF4CD964) : null,
            leading: SizedBox(
              height: 28,
              width: 28,
              child: Center(
                child: Image.asset(
                  'assets/images/strava_logo_icon_170697.png',
                  height: 18,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          _SettingsTile(
            title: !Platform.isIOS
                ? "Wearable detection unavailable"
                : _appleWatchChecking
                ? "Checking wearables..."
                : (_appleWatchDetected == true
                      ? (_wearableDetectedType == 'apple'
                            ? "Apple Watch detected"
                            : "Wearable detected")
                      : "Wearable not detected"),
            subtitle: !Platform.isIOS
                ? "Wearable source detection works on iPhone only"
                : (_appleWatchDetected == true
                      ? (_wearableDetectedType == 'apple'
                            ? "Health data from Apple Watch is available"
                            : "Health data from a connected wearable is available")
                      : "No wearable source found in Apple Health data"),
            icon: _appleWatchChecking ? Icons.hourglass_bottom : Icons.watch,
            onTap: (!Platform.isIOS || _isDeactivated || _appleWatchChecking)
                ? null
                : _handleAppleWatchTap,
            color: _appleWatchDetected == true ? const Color(0xFF4CD964) : null,
            leading: Container(
              height: 28,
              width: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7A7A7A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.watch, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.translate("settings_support"),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            title: t.translate("settings_contact"),
            subtitle: t.translate("settings_contact_sub"),
            icon: Icons.mail_outline,
            onTap: () => _showSupportDialog(
              title: t.translate("settings_contact"),
              body: t.translate("settings_contact_body"),
            ),
          ),
          _SettingsTile(
            title: t.translate("settings_help"),
            subtitle: t.translate("settings_help_sub"),
            icon: Icons.help_outline,
            onTap: () => _showSupportDialog(
              title: t.translate("settings_help"),
              body: t.translate("settings_help_body"),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
    this.leading,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: InkRipple.splashFactory,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          overlayColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.pressed)
                ? Colors.white.withValues(alpha: 0.08)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                leading ?? Icon(icon, color: color ?? AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color ?? Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
