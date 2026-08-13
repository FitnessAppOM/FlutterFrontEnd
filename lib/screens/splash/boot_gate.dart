import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../auth/expert_questionnaire.dart';
import '../../auth/questionnaire.dart';
import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../../core/account_type.dart';
import '../../core/locale_controller.dart';
import '../../main/main_layout.dart';
import '../../screens/daily_journal.dart';
import '../../services/auth/profile_service.dart';
import '../../services/core/navigation_service.dart';
import '../../services/purchases/apple_billing_service.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/taqa_bolt_loading_screen.dart';
import '../account_restore_page.dart';
import '../welcome.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  static const Duration _checkTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    NavigationService.setNotificationNavigationReady(false);
    _boot();
  }

  Future<void> _navigatePostAuth({
    required Map<String, dynamic> profile,
    required bool subscriptionRequired,
  }) async {
    final serverDone = profile["filled_user_questionnaire"] == true;
    final expertQuestionnaireDone =
        profile["filled_expert_questionnaire"] == true;
    final isApprovedExpert = profile["is_expert"] == true;
    final isCoachAccount = AccountType.isCoach(profile);
    final applicationStatus = (profile['expert_profile_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final hasData =
        expertQuestionnaireDone ||
        serverDone ||
        profile['has_questionnaire_data'] == true;
    await Future.wait<void>([
      AccountStorage.setQuestionnaireDone(serverDone),
      AccountStorage.setExpertQuestionnaireDone(expertQuestionnaireDone),
      AccountStorage.setIsExpert(isCoachAccount),
      AccountStorage.setCoachApplicationStatus(
        expertQuestionnaireDone
            ? (applicationStatus.isEmpty ? 'pending' : applicationStatus)
            : null,
      ),
      AccountStorage.setVerifiedSubscriptionAccess(
        required: subscriptionRequired,
        expiresAt: _startupSubscriptionExpiresAt,
      ),
    ]);
    if (!mounted) return;
    if (NavigationService.isOnJournalPage) {
      return;
    }
    // Coach approval and membership are evaluated inside the Coach tab.
    if (hasData) {
      final expertAiPending =
          isApprovedExpert &&
          NavigationService.expertAiUpdatesNotificationPending;
      if (expertAiPending) {
        NavigationService.consumeExpertAiUpdatesNotification();
      }
      final directNotificationTarget = subscriptionRequired
          ? null
          : await NavigationService.consumeDirectNotificationTarget(
              initialSubscriptionRequired: false,
            );
      if (!mounted) return;
      final target = subscriptionRequired
          ? const MainLayout(initialSubscriptionRequired: true)
          : directNotificationTarget ??
                (NavigationService.journalNotificationPending
                    ? const DailyJournalPage()
                    : (NavigationService.dietNotificationPending
                          ? const MainLayout(
                              initialIndex: 0,
                              initialSubscriptionRequired: false,
                            )
                          : (expertAiPending
                                ? const MainLayout(
                                    initialIndex: MainLayout.coachTabIndex,
                                    autoOpenExpertDashboard: true,
                                    initialSubscriptionRequired: false,
                                  )
                                : const MainLayout(
                                    initialSubscriptionRequired: false,
                                  ))));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => target),
        (route) => false,
      );
      if (target is! MainLayout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NavigationService.setNotificationNavigationReady(true);
          NavigationService.flushPendingNotificationNavigation();
        });
      }
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isCoachAccount
              ? const ExpertQuestionnairePage()
              : const QuestionnairePage(),
        ),
        (route) => false,
      );
    }
  }

  DateTime? _startupSubscriptionExpiresAt;

  Future<void> _navigateOfflineMain() async {
    final cachedAccess = await AccountStorage.cachedSubscriptionAccessAllowed();
    // An unknown legacy cache is not proof of paid access. Existing installs
    // must reconnect once to create the dated, server-verified snapshot.
    final cachedSubscriptionRequired = cachedAccess != true;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MainLayout(initialSubscriptionRequired: cachedSubscriptionRequired),
      ),
      (route) => false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        final ctx = NavigationService.navigatorKey.currentContext;
        if (ctx == null) return;
        final t = AppLocalizations.of(ctx);
        AppToast.show(
          ctx,
          t.translate("offline_mode"),
          type: AppToastType.info,
        );
      });
    });
  }

  Future<StartupBootstrapSnapshot> _fetchStartup(int userId) async {
    try {
      final snapshot = await AppleBillingService.fetchStartupBootstrap();
      _startupSubscriptionExpiresAt = snapshot.subscriptionExpiresAt;
      return snapshot;
    } on AppleBillingException catch (error) {
      if (error.statusCode != 404) rethrow;
      final snapshot = await _fetchLegacyStartup(userId);
      _startupSubscriptionExpiresAt = snapshot.subscriptionExpiresAt;
      return snapshot;
    }
  }

  Future<StartupBootstrapSnapshot> _fetchLegacyStartup(int userId) async {
    final accountResponse = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profile/$userId/account-status'),
      headers: await AccountStorage.getAuthHeaders(),
    );
    if (accountResponse.statusCode != 200) {
      await AccountStorage.handleAuthStatus(
        accountResponse.statusCode,
        responseBody: accountResponse.body,
      );
      throw AppleBillingException(
        'Your account could not be checked.',
        statusCode: accountResponse.statusCode,
      );
    }
    var account = <String, dynamic>{};
    try {
      final decoded = jsonDecode(accountResponse.body);
      if (decoded is Map) account = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (account['status']?.toString().trim().toLowerCase() == 'deactivated') {
      return StartupBootstrapSnapshot(
        account: account,
        profile: const <String, dynamic>{},
        subscriptionRequired: false,
      );
    }

    final profile = await ProfileApi.fetchProfile(
      userId,
      lang: localeController.locale.languageCode,
    );
    final normalEntitlement = await AppleBillingService.fetchEntitlement(
      'app_full',
    );
    final coachEntitlement = normalEntitlement.active
        ? null
        : await AppleBillingService.fetchEntitlement('coach_tools');
    final completedOnboarding =
        profile['filled_user_questionnaire'] == true ||
        profile['filled_expert_questionnaire'] == true;
    return StartupBootstrapSnapshot(
      account: account,
      profile: profile,
      subscriptionRequired:
          completedOnboarding &&
          !normalEntitlement.active &&
          !(coachEntitlement?.active ?? false),
      subscriptionExpiresAt: normalEntitlement.active
          ? normalEntitlement.expiresAt
          : coachEntitlement?.expiresAt,
    );
  }

  Future<void> _boot() async {
    final stored = await Future.wait<Object?>([
      AccountStorage.getEmail(),
      AccountStorage.isVerified(),
      AccountStorage.getUserId(),
      AccountStorage.getAccessToken(),
    ]);
    final email = stored[0] as String?;
    final verified = stored[1] as bool;
    final storedUserId = stored[2] as int?;
    final token = stored[3] as String?;
    final hasSession =
        storedUserId != null &&
        storedUserId > 0 &&
        token != null &&
        token.trim().isNotEmpty;

    if (email != null && email.isNotEmpty && verified == true && hasSession) {
      try {
        final startup = await _fetchStartup(
          storedUserId,
        ).timeout(_checkTimeout);
        if (startup.accountDeactivated) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AccountRestorePage(
                initialPayload: startup.account,
                prefilledEmail: email,
              ),
            ),
            (route) => false,
          );
          return;
        }
        await _navigatePostAuth(
          profile: startup.profile,
          subscriptionRequired: startup.subscriptionRequired,
        );
        return;
      } on SocketException {
        await _navigateOfflineMain();
        return;
      } on TimeoutException {
        await _navigateOfflineMain();
        return;
      } on http.ClientException {
        await _navigateOfflineMain();
        return;
      } catch (_) {
        // Auth handling in the bootstrap service may already have navigated.
        final remainingToken = await AccountStorage.getAccessToken();
        if (remainingToken == null || remainingToken.trim().isEmpty) return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WelcomePage(onChangeLanguage: localeController.setLocale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaBoltLoadingScreen.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(24, 24, 24, 24),
            child: const Center(child: TaqaAppLaunchLoader()),
          ),
        ),
      ),
    );
  }
}
