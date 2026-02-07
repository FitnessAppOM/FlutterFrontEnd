import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'package:image_picker/image_picker.dart';
import '../config/base_url.dart';
import '../consents/consent_manager.dart';
import '../auth/expert_questionnaire.dart';
import '../services/core/notification_service.dart';
import '../screens/welcome.dart';

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

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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
      final res = await http.get(url).timeout(const Duration(seconds: 12));
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

  Future<void> _connectWhoop() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(context, "Please log in to connect Whoop.", type: AppToastType.info);
      return;
    }
    setState(() => _whoopLoading = true);
    try {
      final url = "${ApiConfig.baseUrl}/auth/whoop/login?user_id=$userId";
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
      }
      AppToast.show(
        context,
        ok ? "Whoop connected successfully." : "Whoop connect failed.",
        type: ok ? AppToastType.success : AppToastType.error,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, "Whoop connect failed: $e", type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _whoopLoading = false);
    }
  }

  Future<void> _disconnectWhoop() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId == 0) {
      AppToast.show(context, "Please log in.", type: AppToastType.info);
      return;
    }
    setState(() => _whoopLoading = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/whoop/disconnect?user_id=$userId");
      final res = await http.post(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception("Status ${res.statusCode}");
      }
      if (!mounted) return;
      setState(() => _whoopLinked = false);
      AccountStorage.notifyWhoopChanged();
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
