import 'dart:async';

import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';
import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../services/core/notification_service.dart';
import '../services/core/remote_push_service.dart';
import '../services/purchases/apple_billing_service.dart';
import '../services/purchases/taqa_subscription_catalog.dart';
import '../screens/welcome.dart';
import 'expert_questionnaire.dart';

/// Locks coach applicants out of the app until an admin decision is made and,
/// once approved, until their coach membership is started.
class CoachApplicationStatusPage extends StatefulWidget {
  const CoachApplicationStatusPage({
    super.key,
    this.initialStatus,
    this.allowClose = false,
  });

  final String? initialStatus;
  final bool allowClose;

  @override
  State<CoachApplicationStatusPage> createState() =>
      _CoachApplicationStatusPageState();
}

class _CoachApplicationStatusPageState
    extends State<CoachApplicationStatusPage> {
  String _status = 'pending';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialStatus = widget.initialStatus?.trim().toLowerCase();
    if (initialStatus != null && initialStatus.isNotEmpty) {
      _status = initialStatus;
    }
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) throw StateError('Sign in again.');
      final profile = await ProfileApi.fetchProfile(userId);
      final status = (profile['expert_profile_status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      await AccountStorage.setCoachApplicationStatus(
        status.isEmpty ? 'pending' : status,
      );
      if (!mounted) return;
      setState(() {
        _status = status.isEmpty ? 'pending' : status;
      });
      final navigated = await _continueIfCoachMembershipIsActive();
      if (!mounted || navigated) return;
      setState(() => _loading = false);
    } catch (_) {
      final cachedStatus = await AccountStorage.getCoachApplicationStatus();
      if (!mounted) return;
      setState(() {
        if (cachedStatus != null) _status = cachedStatus;
        _error = 'We could not check your application yet. Try again.';
        _loading = false;
      });
    }
  }

  Future<bool> _continueIfCoachMembershipIsActive() async {
    if (_status != 'approved') return false;

    var active = false;
    try {
      final entitlement = await AppleBillingService.fetchEntitlement(
        'coach_tools',
      );
      final expiration = entitlement.expiresAt;
      active =
          entitlement.active &&
          expiration != null &&
          expiration.isAfter(DateTime.now().toUtc());
      if (active) {
        await AccountStorage.setCoachMembershipActive(
          true,
          expiresAt: expiration,
        );
      } else {
        await AccountStorage.setCoachMembershipActive(false);
      }
    } catch (_) {
      // Keep a currently verified, unexpired entitlement usable during a
      // temporary backend outage. It can never outlive its stored expiration.
      active = await AccountStorage.isCoachMembershipActive();
    }
    if (!active || !mounted) return false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
    return true;
  }

  Future<void> _startMembership() async {
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TaqaSubscriptionPage(
          mandatory: true,
          coachMembership: true,
          plans: TaqaSubscriptionCatalog.coachPlans,
        ),
      ),
    );
    if (!mounted || subscribed != true) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
  }

  void _reapply() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ExpertQuestionnairePage()),
    );
  }

  void _close() {
    if (!widget.allowClose || !Navigator.of(context).canPop()) return;
    Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    final userId = await AccountStorage.getUserId();
    await RemotePushService.unregisterTokenForCurrentUser();
    await NotificationService.cancelAccountNotifications(userId: userId);
    await AccountStorage.logoutSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'rejected';
    final approved = _status == 'approved';
    final title = approved
        ? 'Your coach application was accepted'
        : rejected
        ? 'Your coach application was not accepted'
        : 'Your coach application is under review';
    final body = approved
        ? 'Start your Taqa Coach membership to unlock your coach tools and the rest of the app.'
        : rejected
        ? 'You can update your information and submit a new application for review.'
        : 'Our team is reviewing your application. You will be able to continue once it has been accepted.';

    return PopScope(
      canPop: widget.allowClose,
      child: Scaffold(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        appBar: TaqaPageAppBar(
          title: 'Coach application',
          showBackButton: false,
          trailing: widget.allowClose
              ? IconButton(
                  tooltip: 'Close',
                  onPressed: _close,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                )
              : IconButton(
                  tooltip: 'Sign out',
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: TaqaUiScale.w(82),
                  height: TaqaUiScale.w(82),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: approved
                        ? TaqaUiColors.accent
                        : rejected
                        ? TaqaUiColors.recordRed
                        : TaqaUiColors.white,
                  ),
                  child: Icon(
                    approved
                        ? Icons.workspace_premium_rounded
                        : rejected
                        ? Icons.refresh_rounded
                        : Icons.hourglass_top_rounded,
                    size: TaqaUiScale.w(38),
                    color: TaqaUiColors.charcoal,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(24)),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(24),
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.charcoal,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Text(
                  _error ?? body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    height: 1.4,
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.68),
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const CircularProgressIndicator(color: TaqaUiColors.charcoal)
                else if (approved)
                  TaqaFilledButton(
                    label: 'Continue to payment',
                    onTap: _startMembership,
                  )
                else if (rejected)
                  TaqaFilledButton(label: 'Reapply', onTap: _reapply),
                if (widget.allowClose) ...[
                  SizedBox(height: TaqaUiScale.h(8)),
                  TaqaTextActionButton(label: 'Close', onTap: _close),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Coach-tab access state. Unlike [CoachApplicationStatusPage], this is
/// deliberately not an app-wide route: the bottom navigation stays visible
/// while a user applies or starts their coach membership.
class CoachModuleGate extends StatefulWidget {
  const CoachModuleGate({
    super.key,
    this.initialStatus,
    required this.onCoachMembershipReady,
  });

  final String? initialStatus;
  final VoidCallback onCoachMembershipReady;

  @override
  State<CoachModuleGate> createState() => _CoachModuleGateState();
}

class _CoachModuleGateState extends State<CoachModuleGate> {
  String? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus?.trim().toLowerCase();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) throw StateError('Sign in again.');
      final profile = await ProfileApi.fetchProfile(userId);
      final submitted = profile['filled_expert_questionnaire'] == true;
      final rawStatus = (profile['expert_profile_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final status = submitted
          ? (rawStatus.isEmpty ? 'pending' : rawStatus)
          : null;
      await AccountStorage.setExpertQuestionnaireDone(submitted);
      await AccountStorage.setCoachApplicationStatus(status);

      if (status == 'approved') {
        try {
          final entitlement = await AppleBillingService.fetchEntitlement(
            'coach_tools',
          );
          final expiresAt = entitlement.expiresAt;
          final active =
              entitlement.active &&
              expiresAt != null &&
              expiresAt.isAfter(DateTime.now().toUtc());
          await AccountStorage.setCoachMembershipActive(
            active,
            expiresAt: active ? expiresAt : null,
          );
          if (active && mounted) {
            widget.onCoachMembershipReady();
            return;
          }
        } catch (_) {
          // A previously verified, unexpired local entitlement remains valid
          // during a temporary server outage.
          if (await AccountStorage.isCoachMembershipActive() && mounted) {
            widget.onCoachMembershipReady();
            return;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'We could not check your coach access. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _startCoachMembership() async {
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TaqaSubscriptionPage(
          mandatory: true,
          coachMembership: true,
          plans: TaqaSubscriptionCatalog.coachPlans,
          allowPlanTypeSwitch: false,
          allowBackNavigation: true,
        ),
      ),
    );
    if (!mounted || subscribed != true) return;
    await _refresh();
  }

  void _apply() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ExpertQuestionnairePage()));
  }

  @override
  Widget build(BuildContext context) {
    final approved = _status == 'approved';
    final rejected = _status == 'rejected';
    final pending = _status == 'pending';
    final title = approved
        ? 'Coach membership required'
        : rejected
        ? 'Your coach application was not accepted'
        : pending
        ? 'Your coach application is under review'
        : 'Become a Taqa Coach';
    final body = approved
        ? 'Start your Taqa Coach membership to unlock your coach tools.'
        : rejected
        ? 'Update your information and send a new application for review.'
        : pending
        ? 'Our team is reviewing your application. Coach tools will unlock after approval.'
        : 'Apply for coach approval to become eligible for Taqa Coach plans and tools.';
    final icon = approved
        ? Icons.lock_outline_rounded
        : rejected
        ? Icons.refresh_rounded
        : pending
        ? Icons.hourglass_top_rounded
        : Icons.workspace_premium_rounded;

    return ColoredBox(
      color: TaqaUiColors.unnamedColorE3e3e3,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: TaqaUiScale.insetsLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: TaqaUiScale.w(82),
                    height: TaqaUiScale.w(82),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: TaqaUiColors.accent,
                    ),
                    child: Icon(
                      icon,
                      size: TaqaUiScale.w(38),
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(24),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(12)),
                  Text(
                    _error ?? body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      height: 1.4,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.68),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(28)),
                  if (_loading)
                    const CircularProgressIndicator(
                      color: TaqaUiColors.charcoal,
                    )
                  else if (approved)
                    TaqaFilledButton(
                      label: 'View coach plans',
                      onTap: _startCoachMembership,
                    )
                  else if (!pending)
                    TaqaFilledButton(
                      label: rejected
                          ? 'Apply again'
                          : 'Apply to become a coach',
                      onTap: _apply,
                    ),
                  if (!_loading && !approved) ...[
                    SizedBox(height: TaqaUiScale.h(8)),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Refresh'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
