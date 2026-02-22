import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
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
import '../config/base_url.dart';
import '../consents/consent_manager.dart';
import '../auth/expert_questionnaire.dart';
import '../services/core/notification_service.dart';
import '../services/whoop/whoop_daily_sync.dart';
import '../services/whoop/whoop_latest_service.dart';
import '../services/fitbit/fitbit_daily_sync.dart';
import '../screens/welcome.dart';
import '../widgets/Main/card_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _usernameController = TextEditingController();
  bool _updatingUsername = false;
  bool _updatingAvatar = false;
  bool _deletingAccount = false;
  String? _email;
  bool _expertQuestionnaireDone = false;
  bool _whoopLinked = false;
  bool _whoopLoading = false;
  bool _fitbitLinked = false;
  bool _fitbitLoading = false;
  bool _fitbitAuthInFlight = false;

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
  final _newsTitleCtrl = TextEditingController();
  final _newsSubtitleCtrl = TextEditingController();
  final _newsContentCtrl = TextEditingController();
  String _newsTag = "Article";
  String? _newsPdfUrl;
  bool _newsSaving = false;

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
  }

  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.accent, size: 42),
              const SizedBox(height: 12),
              Text(
                t.translate("settings"),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
                                await Clipboard.setData(ClipboardData(text: token.trim()));
                                if (!context.mounted) return;
                                AppToast.show(context, "Token copied", type: AppToastType.success);
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
    _newsTitleCtrl.dispose();
    _newsSubtitleCtrl.dispose();
    _newsContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewsPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ["pdf"],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    setState(() => _newsSaving = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/news/upload");
      final request = http.MultipartRequest("POST", url);
      final headers = await AccountStorage.getAuthHeaders();
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath("file", path));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception(body);
      }
      final data = json.decode(body) as Map<String, dynamic>;
      setState(() => _newsPdfUrl = data["url"]?.toString());
    } catch (e) {
      AppToast.show(context, "Upload failed: $e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _newsSaving = false);
    }
  }

  Future<void> _createNewsItem() async {
    if (_newsSaving) return;
    FocusScope.of(context).unfocus();
    final title = _newsTitleCtrl.text.trim();
    final subtitle = _newsSubtitleCtrl.text.trim();
    if (title.isEmpty || subtitle.isEmpty) {
      AppToast.show(context, "Title and subtitle are required", type: AppToastType.info);
      return;
    }
    if (_newsTag == "Article" &&
        _newsContentCtrl.text.trim().isEmpty &&
        _newsPdfUrl == null) {
      AppToast.show(context, "Add content or upload a PDF", type: AppToastType.info);
      return;
    }
    setState(() => _newsSaving = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/news");
      final headers = {
        "Content-Type": "application/json",
        ...await AccountStorage.getAuthHeaders(),
      };
      final body = json.encode({
        "title": title,
        "subtitle": subtitle,
        "tag": _newsTag,
        "content": _newsContentCtrl.text.trim(),
        "content_url": _newsPdfUrl,
      });
      final res = await http.post(url, headers: headers, body: body);
      if (res.statusCode != 200) {
        throw Exception(res.body);
      }
      AppToast.show(context, "News added", type: AppToastType.success);
      _newsTitleCtrl.clear();
      _newsSubtitleCtrl.clear();
      _newsContentCtrl.clear();
      setState(() {
        _newsPdfUrl = null;
        _newsTag = "Article";
      });
    } catch (e) {
      AppToast.show(context, "Failed to add news: $e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _newsSaving = false);
    }
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
    final done = await AccountStorage.isExpertQuestionnaireDone();
    if (mounted) {
      setState(() => _expertQuestionnaireDone = done);
    }
  }

  Future<void> _loadWhoopStatus() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      setState(() => _whoopLinked = false);
      return;
    }
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/whoop/status?user_id=$userId");
      final headers = await AccountStorage.getAuthHeaders();
      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _whoopLinked = data["linked"] == true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _whoopLinked = false);
    }
  }

  Future<void> _loadFitbitStatus() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) {
        setState(() => _fitbitLinked = false);
        return;
      }
      final url = Uri.parse("${ApiConfig.baseUrl}/fitbit/status?user_id=$userId");
      final headers = await AccountStorage.getAuthHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) {
        setState(() => _fitbitLinked = false);
        return;
      }
      final data = json.decode(response.body);
      setState(() => _fitbitLinked = data["linked"] == true);
    } catch (_) {
      setState(() => _fitbitLinked = false);
    }
  }

  Future<void> _connectWhoop() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(context, "Please log in to connect Whoop.", type: AppToastType.info);
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
        AccountStorage.notifyWhoopChanged();
        AccountStorage.notifyAccountChanged();
        try {
          await WhoopDailySync().forceBackfillRecent();
          await WhoopDailySync().pushIfNewDay();
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
      AppToast.show(context, "Whoop connect failed: $e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _whoopLoading = false);
    }
  }

  Future<void> _connectFitbit() async {
    if (_fitbitAuthInFlight) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(context, "Please log in to connect Fitbit.", type: AppToastType.info);
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
        AccountStorage.notifyAccountChanged();
        try {
          await FitbitDailySync().forceBackfillRecent();
          await FitbitDailySync().pushIfNewDay();
          AccountStorage.notifyAccountChanged();
        } catch (_) {}
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
      AppToast.show(context, "Fitbit connect failed: $e", type: AppToastType.error);
    } finally {
      _fitbitAuthInFlight = false;
      if (mounted) setState(() => _fitbitLoading = false);
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
      final url = Uri.parse("${ApiConfig.baseUrl}/fitbit/disconnect?user_id=$userId");
      final headers = await AccountStorage.getAuthHeaders();
      await http.post(url, headers: headers);
      setState(() => _fitbitLinked = false);
      AccountStorage.notifyAccountChanged();
      AppToast.show(context, "Fitbit disconnected.", type: AppToastType.success);
    } catch (e) {
      AppToast.show(context, "Fitbit disconnect failed: $e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _fitbitLoading = false);
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
      final url = Uri.parse("${ApiConfig.baseUrl}/whoop/disconnect?user_id=$userId");
      final headers = await AccountStorage.getAuthHeaders();
      final res =
          await http.post(url, headers: headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      if (!mounted) return;
      setState(() => _whoopLinked = false);
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
      await AccountStorage.setAvatarUrl(url);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            body,
            style: const TextStyle(color: Colors.white70),
          ),
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
    _usernameController.text = await AccountStorage.getName() ?? "";

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
              onPressed: _updatingUsername ? null : () async {
                final newUsername = _usernameController.text.trim();
                final currentUsername = await AccountStorage.getName() ?? "";
                if (newUsername.isEmpty || newUsername == currentUsername) {
                  Navigator.pop(ctx);
                  return;
                }
                setState(() => _updatingUsername = true);
                try {
                  final userId = await AccountStorage.getUserId();
                  if (userId == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.translate("user_missing"))),
                    );
                    setState(() => _updatingUsername = false);
                    return;
                  }
                  final updated = await ProfileApi.updateUsername(userId, newUsername);
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

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: AppColors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            onTap: _promptChangeUsername,
          ),
          _SettingsTile(
            title: t.translate("settings_change_avatar"),
            subtitle: t.translate("settings_change_avatar_sub"),
            icon: _updatingAvatar ? Icons.hourglass_bottom : Icons.image_outlined,
            onTap: _pickAvatar,
          ),
          _SettingsTile(
            title: t.translate("settings_be_expert"),
            subtitle: t.translate("settings_be_expert_sub"),
            icon: Icons.work_outline,
            onTap: () async {
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
                final lang = AppLocalizations.of(context).locale.languageCode;
                final profile = await ProfileApi.fetchProfile(userId, lang: lang);
                final done = profile["filled_expert_questionnaire"] == true;
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
            onTap: () {
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
          _SettingsTile(
            title: t.translate("settings_delete_account"),
            subtitle: t.translate("settings_delete_account_sub"),
            icon: _deletingAccount ? Icons.hourglass_bottom : Icons.delete_forever,
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
            subtitle:
                _whoopLinked ? "Disconnect your Whoop" : "Link your Whoop account",
            icon: _whoopLoading ? Icons.hourglass_bottom : Icons.monitor_heart,
            onTap: _whoopLoading ? null : _handleWhoopTap,
            color: _whoopLinked ? const Color(0xFF4CD964) : null,
            leading: Container(
              height: 28,
              width: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2D7CFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "W",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          _SettingsTile(
            title: _fitbitLinked ? "Fitbit connected" : "Connect Fitbit",
            subtitle:
                _fitbitLinked ? "Disconnect your Fitbit" : "Link your Fitbit account",
            icon: _fitbitLoading ? Icons.hourglass_bottom : Icons.directions_walk,
            onTap: _fitbitLoading ? null : _handleFitbitTap,
            color: _fitbitLinked ? const Color(0xFF4CD964) : null,
            leading: Container(
              height: 28,
              width: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF00B0B9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "F",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "News testing",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _newsTitleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Title",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newsSubtitleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Subtitle",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _newsTag,
                  dropdownColor: const Color(0xFF1E1E1E),
                  decoration: const InputDecoration(
                    labelText: "Tag",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Article", child: Text("Article")),
                    DropdownMenuItem(value: "Apply", child: Text("Apply")),
                    DropdownMenuItem(value: "Journal", child: Text("Journal")),
                    DropdownMenuItem(value: "Update", child: Text("Update")),
                    DropdownMenuItem(value: "Nutrition", child: Text("Nutrition")),
                    DropdownMenuItem(value: "Workout", child: Text("Workout")),
                    DropdownMenuItem(value: "Reminder", child: Text("Reminder")),
                  ],
                  onChanged: (v) => setState(() => _newsTag = v ?? "Article"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newsContentCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Content (optional)",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                if (_newsTag == "Article") ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _newsPdfUrl == null ? "No PDF uploaded" : "PDF uploaded",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _newsSaving ? null : _pickNewsPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Upload PDF"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _newsSaving ? null : _createNewsItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_newsSaving ? "Saving..." : "Add News"),
                  ),
                ),
              ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
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
    );
  }
}
