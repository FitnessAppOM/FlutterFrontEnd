import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/account_storage.dart';
import '../core/account_type.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_mini_tag.dart';
import '../TaqaUI/components/taqa_pressable.dart';
import '../TaqaUI/components/taqa_profile_info_section.dart';
import '../TaqaUI/components/taqa_text_field.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../auth/questionnaire.dart';
import '../screens/daily_journal.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/core/daily_provider_push_service.dart';
import '../screens/welcome.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../core/user_friendly_error.dart';

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
    final t = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppToast.show(context, t.translate("required"), type: AppToastType.error);
      return;
    }
    setState(() => _requesting = true);
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) {
        throw Exception(t.translate("please_login_again"));
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
        userFriendlyErrorMessage(e),
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
        userFriendlyErrorMessage(e),
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
        refreshToken: result['refresh_token']?.toString(),
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
        userFriendlyErrorMessage(e),
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
      final isApprovedExpert = profile["is_expert"] == true;
      final isCoachAccount = AccountType.isCoach(profile);
      final approvedCoach = AccountType.isApprovedCoach(profile);
      final hasData = serverDone;
      await AccountStorage.setQuestionnaireDone(serverDone);
      await AccountStorage.setExpertQuestionnaireDone(
        expertQuestionnaireDone || approvedCoach,
      );
      await AccountStorage.setIsExpert(isCoachAccount);
      if (!mounted) return;
      if (hasData) {
        final expertAiPending =
            isApprovedExpert &&
            NavigationService.expertAiUpdatesNotificationPending;
        if (expertAiPending) {
          NavigationService.consumeExpertAiUpdatesNotification();
        }
        final directNotificationTarget =
            await NavigationService.consumeDirectNotificationTarget();
        if (!mounted) return;
        final target =
            directNotificationTarget ??
            (NavigationService.journalNotificationPending
                ? const DailyJournalPage()
                : (NavigationService.dietNotificationPending
                      ? const MainLayout(initialIndex: 0)
                      : (expertAiPending
                            ? const MainLayout(
                                initialIndex: MainLayout.coachTabIndex,
                                autoOpenExpertDashboard: true,
                              )
                            : const MainLayout())));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => target),
          (_) => false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationService.setNotificationNavigationReady(true);
          NavigationService.flushPendingNotificationNavigation();
        });
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const QuestionnairePage()),
          (_) => false,
        );
      }
    } catch (_) {
      final questionnaireDone = await AccountStorage.isQuestionnaireDone();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => questionnaireDone
              ? const MainLayout()
              : const QuestionnairePage(),
        ),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isCodeStep = _step == _RestoreStep.code;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: t.translate("account_restore_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        leading: isCodeStep
            ? TaqaBackButton(
                onPressed: _requesting || _confirming
                    ? () {}
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _step = _RestoreStep.info);
                      },
              )
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      minHeight: constraints.maxHeight - TaqaUiScale.h(40),
                    ),
                    child: IntrinsicHeight(
                      child: isCodeStep ? _buildCodeStep(t) : _buildInfoStep(t),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep(AppLocalizations t) {
    final busy = _requesting || _deleting;
    final canRequest = !busy && _emailController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RestoreIntroCard(
          stepLabel: '1 / 2',
          icon: Icons.restore_rounded,
          title: t.translate("account_restore_subtitle"),
          body: t.translate("account_restore_body"),
        ),
        SizedBox(height: TaqaUiScale.h(16)),
        if (_deadline != null) ...[
          TaqaProfileInfoSection(
            items: [
              TaqaProfileInfoItem(
                label: t.translate("account_reactivable_until"),
                value: _deadline!,
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(16)),
        ],
        TaqaTextField(
          controller: _emailController,
          label: t.translate("account_restore_email_label"),
          hint: t.translate("email_hint"),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !busy,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
        ),
        const Spacer(),
        SizedBox(height: TaqaUiScale.h(32)),
        TaqaFilledButton(
          label: t.translate("account_restore_send_code"),
          loading: _requesting,
          onTap: canRequest ? _requestCode : null,
        ),
        SizedBox(height: TaqaUiScale.h(6)),
        TaqaTextActionButton(
          label: t.translate("account_restore_not_now"),
          onTap: busy ? null : _closeRestorePrompt,
        ),
        SizedBox(height: TaqaUiScale.h(6)),
        _RestoreDeleteButton(
          label: t.translate("settings_delete_account"),
          loading: _deleting,
          onTap: busy ? null : _deleteAccount,
        ),
      ],
    );
  }

  Widget _buildCodeStep(AppLocalizations t) {
    final busy = _confirming || _requesting;
    final canConfirm = !busy && _codeController.text.trim().length == 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RestoreIntroCard(
          stepLabel: '2 / 2',
          icon: Icons.mark_email_read_outlined,
          title: t.translate("account_restore_code_title"),
          body:
              '${t.translate("account_restore_code_body")} ${_emailController.text.trim()}',
        ),
        SizedBox(height: TaqaUiScale.h(20)),
        TaqaTextField(
          controller: _codeController,
          label: t.translate("account_restore_code_title"),
          hint: t.translate("hint_code"),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !busy,
          autofillHints: const [AutofillHints.oneTimeCode],
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: TaqaUiScale.h(6)),
        TaqaTextActionButton(
          label: t.translate("resend_btn"),
          onTap: busy ? null : _requestCode,
        ),
        const Spacer(),
        SizedBox(height: TaqaUiScale.h(32)),
        TaqaFilledButton(
          label: t.translate("account_reactivate_action"),
          loading: _confirming,
          onTap: canConfirm ? _confirmCode : null,
        ),
        SizedBox(height: TaqaUiScale.h(6)),
        TaqaTextActionButton(
          label: t.translate("account_restore_not_now"),
          onTap: busy ? null : _closeRestorePrompt,
        ),
      ],
    );
  }
}

class _RestoreIntroCard extends StatelessWidget {
  const _RestoreIntroCard({
    required this.stepLabel,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String stepLabel;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: TaqaUiScale.w(38),
                height: TaqaUiScale.h(38),
                decoration: const BoxDecoration(
                  color: TaqaUiColors.charcoal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: TaqaUiColors.lime,
                  size: TaqaUiScale.w(20),
                ),
              ),
              const Spacer(),
              TaqaMiniTag(label: stepLabel),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(18)),
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(25),
              fontWeight: FontWeight.w700,
              height: 1,
              color: TaqaUiColors.charcoal,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Text(
            body,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w300,
              height: 18 / 15,
              color: TaqaUiColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreDeleteButton extends StatelessWidget {
  const _RestoreDeleteButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return TaqaPressable(
      semanticLabel: label,
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: TaqaUiColors.recordRed.withValues(alpha: enabled ? 1 : 0.35),
          ),
          borderRadius: TaqaUiScale.radius(5),
        ),
        child: loading
            ? const TaqaLoadingIndicator(
                size: 16,
                color: TaqaUiColors.recordRed,
              )
            : Text(
                taqaUppercase(label),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(10),
                  fontWeight: FontWeight.w600,
                  color: TaqaUiColors.recordRed.withValues(
                    alpha: enabled ? 1 : 0.35,
                  ),
                ),
              ),
      ),
    );
  }
}
