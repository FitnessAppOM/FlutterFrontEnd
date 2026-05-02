import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../auth/questionnaire.dart';
import '../auth/expert_questionnaire.dart';
import '../screens/daily_journal.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/core/daily_provider_push_service.dart';
import '../screens/welcome.dart';

class AccountRestorePage extends StatefulWidget {
  const AccountRestorePage({
    super.key,
    this.initialPayload,
    this.prefilledEmail,
  });

  final Map<String, dynamic>? initialPayload;
  final String? prefilledEmail;

  @override
  State<AccountRestorePage> createState() => _AccountRestorePageState();
}

enum _RestoreStep { info, code }

class _AccountRestorePageState extends State<AccountRestorePage> {
  _RestoreStep _step = _RestoreStep.info;
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _requesting = false;
  bool _confirming = false;
  bool _deleting = false;
  bool _hasActiveSession = false;
  String? _deadline;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
    }
    _extractDeadline();
    _loadSessionState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _extractDeadline() {
    final payload = widget.initialPayload;
    if (payload == null) return;
    final detail = payload['detail']?.toString() ?? '';
    final reactivableUntil = payload['reactivable_until']?.toString();
    final scheduledPurge = payload['scheduled_purge_at']?.toString();
    if (reactivableUntil != null && reactivableUntil.isNotEmpty) {
      _deadline = _displayDate(reactivableUntil);
    } else if (scheduledPurge != null && scheduledPurge.isNotEmpty) {
      _deadline = _displayDate(scheduledPurge);
    } else {
      final match = RegExp(
        r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+\-]\d{2}:\d{2})?)',
      ).firstMatch(detail);
      if (match != null) {
        _deadline = _displayDate(match.group(1)!);
      }
    }
  }

  Future<void> _loadSessionState() async {
    final userId = await AccountStorage.getUserId();
    final token = await AccountStorage.getAccessToken();
    final hasSession =
        userId != null &&
        userId > 0 &&
        token != null &&
        token.trim().isNotEmpty;
    if (!mounted) return;
    setState(() => _hasActiveSession = hasSession);
  }

  String _displayDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
  }

  Future<void> _closeRestorePrompt() async {
    await AccountStorage.dismissDeactivatedPrompt();
    if (_hasActiveSession) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (_) => false,
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
      (_) => false,
    );
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppToast.show(
        context,
        "Please enter your email.",
        type: AppToastType.error,
      );
      return;
    }
    setState(() => _requesting = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) {
        throw Exception("Please log in and try again.");
      }
      await ProfileApi.requestReactivation(userId);
      if (!mounted) return;
      setState(() => _step = _RestoreStep.code);
      AppToast.show(
        context,
        AppLocalizations.of(context).translate("account_restore_code_sent"),
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
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final t = AppLocalizations.of(context);
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId <= 0) {
      AppToast.show(
        context,
        t.translate("user_missing"),
        type: AppToastType.error,
      );
      return;
    }
    setState(() => _deleting = true);
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
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _confirmCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      AppToast.show(
        context,
        AppLocalizations.of(context).translate("code_invalid"),
        type: AppToastType.error,
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final result = await ProfileApi.confirmReactivation(email, code);
      if (!mounted) return;

      final rawId = result['user_id'] ?? result['id'];
      final int userId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '') ?? 0;
      final accessToken = (result['access_token'] ?? result['token'])
          ?.toString()
          .trim();
      final provider = (result['provider'] ?? 'local').toString();
      final name =
          (result['name'] ?? result['username'] ?? email.split('@').first)
              .toString();

      if (userId <= 0 || accessToken == null || accessToken.isEmpty) {
        AppToast.show(
          context,
          AppLocalizations.of(context).translate("account_restore_failed"),
          type: AppToastType.error,
        );
        return;
      }

      await AccountStorage.saveUserSession(
        userId: userId,
        email: email,
        name: name,
        verified: true,
        token: accessToken,
        isExpert: false,
        questionnaireDone: false,
        expertQuestionnaireDone: false,
        authProvider: provider,
      );

      if (!mounted) return;

      AppToast.show(
        context,
        AppLocalizations.of(context).translate("account_restore_success"),
        type: AppToastType.success,
      );

      NotificationService.refreshDailyJournalRemindersForCurrentUser();
      DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});

      await _navigatePostRestore(userId: userId);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _navigatePostRestore({required int userId}) async {
    try {
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final serverDone = profile["filled_user_questionnaire"] == true;
      final expertQuestionnaireDone =
          profile["filled_expert_questionnaire"] == true;
      final expertProfileStatus = (profile["expert_profile_status"] ?? "")
          .toString()
          .trim()
          .toLowerCase();
      final isExpert =
          profile["has_expert_profile"] == true ||
          expertQuestionnaireDone ||
          expertProfileStatus == "approved" ||
          expertProfileStatus == "pending";
      final hasData = serverDone || _hasQuestionnaireData(profile);
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(expertQuestionnaireDone);
      await AccountStorage.setIsExpert(isExpert);
      if (!mounted) return;
      if (hasData) {
        final target = NavigationService.journalNotificationPending
            ? const DailyJournalPage()
            : (NavigationService.dietNotificationPending
                  ? const MainLayout(initialIndex: 2)
                  : const MainLayout());
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => target),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => isExpert
                ? const ExpertQuestionnairePage()
                : const QuestionnairePage(),
          ),
          (_) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (_) => false,
      );
    }
  }

  bool _hasQuestionnaireData(Map<String, dynamic> profile) {
    const keys = [
      "age",
      "fitness_goal",
      "training_days",
      "diet_type",
      "height_cm",
      "weight_kg",
      "sex",
    ];
    return keys.any((k) {
      final v = profile[k];
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty && s != "null";
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("account_restore_title")),
        actions: [
          TextButton(
            onPressed: _closeRestorePrompt,
            child: Text(t.translate("account_restore_not_now")),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _step == _RestoreStep.info
            ? _buildInfoStep(t)
            : _buildCodeStep(t),
      ),
    );
  }

  Widget _buildInfoStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate("account_restore_subtitle"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t.translate("account_restore_body"),
          style: const TextStyle(color: Colors.white70),
        ),
        if (_deadline != null) ...[
          const SizedBox(height: 12),
          _StatusRow(
            label: t.translate("account_reactivable_until"),
            value: _deadline!,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          t.translate("account_restore_email_label"),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t.translate("email_hint"),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requesting ? null : _requestCode,
            child: _requesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.translate("account_restore_send_code")),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _closeRestorePrompt,
            child: Text(t.translate("account_restore_not_now")),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _deleting ? null : _deleteAccount,
            child: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.translate("settings_delete_account")),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate("account_restore_code_title"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "${t.translate("account_restore_code_body")} ${_emailController.text.trim()}",
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: t.translate("hint_code"),
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 16,
              letterSpacing: 2,
            ),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _requesting ? null : _requestCode,
            child: _requesting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    t.translate("resend_btn"),
                    style: const TextStyle(color: AppColors.accent),
                  ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirming ? null : _confirmCode,
            child: _confirming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.translate("account_reactivate_action")),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _closeRestorePrompt,
            child: Text(t.translate("account_restore_not_now")),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
