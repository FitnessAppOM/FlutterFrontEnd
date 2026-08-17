import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'pages/train_page.dart';
import 'pages/diet_page.dart';
import 'pages/community_page.dart';
import '../core/account_storage.dart';
import '../core/account_type.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/screenings/screening_prompt_service.dart';
import '../services/training/training_activity_service.dart';
import '../screens/coach_page.dart';
import '../screens/expert_dashboard_page.dart';
import '../TaqaUI/components/taqa_bottom_nav_bar.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';
import '../TaqaUI/screens/taqa_intro_module.dart';
import '../TaqaUI/screens/taqa_post_purchase_intro_page.dart';
import '../services/purchases/apple_billing_service.dart';
import '../services/purchases/taqa_subscription_catalog.dart';
import '../auth/coach_application_status_page.dart';
import '../widgets/taqa_bolt_loading_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({
    super.key,
    this.initialIndex = _dashboardTab,
    this.autoOpenExpertDashboard = false,
    this.initialSubscriptionRequired,
  });

  static const int _dietTab = 0;
  static const int _trainTab = 1;
  static const int _dashboardTab = 2;
  static const int _communityTab = 3;
  static const int _coachTab = 4;

  /// Public alias of [_coachTab] so callers outside this file (login/boot/
  /// welcome/restore redirects, notification handlers, ...) can target the
  /// embedded Coach tab without duplicating the index.
  static const int coachTabIndex = _coachTab;

  final int initialIndex;

  /// When true and [initialIndex] is [coachTabIndex], the Coach tab is
  /// populated with [ExpertDashboardPage] immediately on startup, skipping
  /// the expert/client portal-choice dialog — used by entry points that
  /// already know the user is an expert (login redirect, boot gate,
  /// welcome flow, account restore, notification taps). The dialog still
  /// shows when a user manually taps the Coach tab in the bottom nav.
  final bool autoOpenExpertDashboard;

  /// Server-verified access state supplied by the cold-start bootstrap. When
  /// present, the first layout avoids repeating the entitlement request.
  final bool? initialSubscriptionRequired;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  late int _index;
  bool _expertStatusRefreshedThisSession = false;
  bool _subscriptionGateChecked = false;
  bool _subscriptionGateInProgress = false;
  bool _accessGatesResolved = false;
  bool _postPurchaseIntroInProgress = false;

  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();
  final GlobalKey<DietPageState> _dietKey = GlobalKey<DietPageState>();
  final GlobalKey<TrainPageState> _trainKey = GlobalKey<TrainPageState>();

  late final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountStorage.subscriptionChange.addListener(_handleSubscriptionChanged);
    final idx = widget.initialIndex;
    _index = (idx >= 0 && idx < 5) ? idx : 0;
    _pages[_index] = _buildPage(_index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolveAccessGates());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AccountStorage.subscriptionChange.removeListener(
      _handleSubscriptionChanged,
    );
    super.dispose();
  }

  void _handleSubscriptionChanged() {
    if (!mounted || !_accessGatesResolved) return;
    unawaited(_enforceSubscriptionGate(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_accessGatesResolved) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      unawaited(_refreshAccessAndPendingNotification());
    });
  }

  Future<void> _refreshAccessAndPendingNotification() async {
    await _enforceSubscriptionGate(force: true);
    if (!mounted) return;
    await NavigationService.flushPendingNotificationNavigation();
  }

  Future<void> _resolveAccessGates() async {
    await _enforceAccessGates();
    if (!mounted) return;
    setState(() => _accessGatesResolved = true);
    // The Coach tab has two independent tours. Wait until the portal choice
    // resolves before deciding whether to show the client or expert guide.
    if (_index != MainLayout._coachTab) {
      await _showPostPurchaseIntroIfNeeded(_index);
    }
    if (!mounted) return;
    if (_index == MainLayout._coachTab) {
      unawaited(_openCoach(autoOpen: widget.autoOpenExpertDashboard));
    }
    NavigationService.setNotificationNavigationReady(true);
    NavigationService.flushPendingNotificationNavigation();
    ScreeningPromptService.checkAndPromptIfDue();
  }

  Future<void> _showPostPurchaseIntroIfNeeded(
    int tabIndex, {
    TaqaIntroModule? moduleOverride,
  }) async {
    if (_postPurchaseIntroInProgress) return;
    final module = moduleOverride ?? _introModuleForTab(tabIndex);
    final shouldShow = await AccountStorage.shouldShowPostPurchaseIntroModule(
      module.storageKey,
    );
    if (!shouldShow || !mounted || _index != tabIndex) return;

    _postPurchaseIntroInProgress = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => TaqaPostPurchaseIntroPage(module: module),
        ),
      );
    } finally {
      _postPurchaseIntroInProgress = false;
    }
  }

  TaqaIntroModule _introModuleForTab(int tabIndex) => switch (tabIndex) {
    MainLayout._dietTab => TaqaIntroModule.diet,
    MainLayout._trainTab => TaqaIntroModule.training,
    MainLayout._dashboardTab => TaqaIntroModule.dashboard,
    MainLayout._communityTab => TaqaIntroModule.community,
    MainLayout._coachTab => TaqaIntroModule.clientCoach,
    _ => TaqaIntroModule.dashboard,
  };

  void _queuePostPurchaseIntro(
    int tabIndex, {
    TaqaIntroModule? moduleOverride,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      unawaited(
        _showPostPurchaseIntroIfNeeded(
          tabIndex,
          moduleOverride: moduleOverride,
        ),
      );
    });
  }

  Future<void> _enforceAccessGates() async {
    // A normal subscription is the only app-wide gate. Coach approval and
    // coach membership are intentionally evaluated only when the Coach tab
    // is opened, so all other tabs remain available.
    await _enforceSubscriptionGate();
  }

  Future<void> _enforceSubscriptionGate({bool force = false}) async {
    if (_subscriptionGateInProgress) return;
    if (_subscriptionGateChecked && !force) return;
    _subscriptionGateChecked = true;
    _subscriptionGateInProgress = true;

    try {
      final cachedAccess =
          await AccountStorage.cachedSubscriptionAccessAllowed();
      var subscriptionRequired = cachedAccess == null
          ? widget.initialSubscriptionRequired ??
                await AccountStorage.isSubscriptionRequired()
          : !cachedAccess;
      if (force || widget.initialSubscriptionRequired == null) {
        final completedOnboarding =
            await AccountStorage.isQuestionnaireDone() ||
            await AccountStorage.isExpertQuestionnaireDone();
        if (!completedOnboarding) return;
        try {
          final normalEntitlement = await AppleBillingService.fetchEntitlement(
            'app_full',
          );
          // Coach plans include the full app. Older linked coach purchases may
          // have only persisted `coach_tools`, so accept that entitlement too.
          final coachEntitlement = normalEntitlement.active
              ? null
              : await AppleBillingService.fetchEntitlement('coach_tools');
          subscriptionRequired =
              !normalEntitlement.active && !(coachEntitlement?.active ?? false);
          final activeEntitlement = normalEntitlement.active
              ? normalEntitlement
              : coachEntitlement;
          await AccountStorage.setVerifiedSubscriptionAccess(
            required: subscriptionRequired,
            expiresAt: activeEntitlement?.expiresAt,
          );
        } catch (_) {
          // Keep the last verified state during a temporary backend outage.
        }
      }
      unawaited(
        _syncSubscriptionNotificationsInBackground(
          hasSubscriptionAccess: !subscriptionRequired,
        ),
      );
      if (!subscriptionRequired || !mounted) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const TaqaSubscriptionPage(mandatory: true),
        ),
      );
    } finally {
      _subscriptionGateInProgress = false;
    }
  }

  Future<void> _syncSubscriptionNotificationsInBackground({
    required bool hasSubscriptionAccess,
  }) async {
    try {
      await NotificationService.syncForSubscriptionAccess(
        active: hasSubscriptionAccess,
      );
    } catch (_) {
      // Subscription enforcement must not wait on notification maintenance.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessGatesResolved) {
      return const TaqaAppLaunchLoadingScreen();
    }

    final isDarkPage = _index == MainLayout._dietTab;
    return Scaffold(
      backgroundColor: isDarkPage
          ? const Color(0xFF121212)
          : AppColors.appBackground,
      body: IndexedStack(
        index: _index,
        children: List.generate(5, (i) => _pages[i] ?? const SizedBox.shrink()),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MinimizedWorkoutBar(
            onExpand: _openActiveWorkout,
            onDiscard: _discardActiveWorkout,
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Future<void> _openActiveWorkout() async {
    if (_index != MainLayout._trainTab) {
      setState(() {
        _index = MainLayout._trainTab;
        _pages[MainLayout._trainTab] ??= _buildPage(MainLayout._trainTab);
      });
      // Let the Train tab build before driving its launcher.
      await WidgetsBinding.instance.endOfFrame;
      await _showPostPurchaseIntroIfNeeded(MainLayout._trainTab);
    }
    if (!mounted) return;
    await _trainKey.currentState?.openActiveWorkoutLauncher();
  }

  Future<void> _discardActiveWorkout() async {
    await TrainingActivityService.stopSession();
    AccountStorage.notifyTrainingChanged();
  }

  void _selectTab(int idx) {
    if (idx < 0 || idx > 4) return;
    if (idx == MainLayout._coachTab) {
      _openCoach();
      return;
    }
    setState(() {
      _index = idx;
      _pages[idx] ??= _buildPage(idx);
    });
    _queuePostPurchaseIntro(idx);
    if (idx == MainLayout._dashboardTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dashboardKey.currentState?.refreshLiveSteps();
      });
    }
    if (idx == MainLayout._dietTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final selectedDate = _dashboardKey.currentState?.selectedDate;
        if (selectedDate != null) {
          await _dietKey.currentState?.syncSelectedDate(selectedDate);
          return;
        }
        await _dietKey.currentState?.refreshTrainingLock();
        await _dietKey.currentState?.refreshTargetsAndMeals();
      });
    }
  }

  Future<void> _refreshExpertStatusInBackground() async {
    if (!mounted) return;
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final filledExpertQuestionnaire =
          profile["filled_expert_questionnaire"] == true;
      final isExpert = AccountType.isCoach(profile);
      final applicationStatus = (profile['expert_profile_status'] ?? '')
          .toString()
          .trim();
      await AccountStorage.setExpertQuestionnaireDone(
        filledExpertQuestionnaire,
      );
      await AccountStorage.setIsExpert(isExpert);
      await AccountStorage.setCoachApplicationStatus(
        filledExpertQuestionnaire
            ? (applicationStatus.isEmpty ? 'pending' : applicationStatus)
            : null,
      );
    } catch (_) {
      // Best-effort refresh; the cached value from before this tap is
      // still used for the current navigation decision either way.
    }
  }

  Future<void> _openCoach({bool autoOpen = false}) async {
    // Use the fast local cache to decide instantly instead of blocking the
    // whole tap on a network round-trip (ProfileApi.fetchProfile) the way
    // _resolveIsExpert() used to — that's what made this tab feel slow next
    // to the other 4, which are just local IndexedStack switches. Refresh
    // the cached value in the background so it's accurate next time.
    final isExpert = await AccountStorage.isExpert();
    final applicationStatus = await AccountStorage.getCoachApplicationStatus();
    final hasActiveCoachMembership =
        await AccountStorage.isCoachMembershipActive();
    if (!mounted) return;
    if (!_expertStatusRefreshedThisSession) {
      _expertStatusRefreshedThisSession = true;
      unawaited(_refreshExpertStatusInBackground());
    }

    final isVerifiedCoach = isExpert && applicationStatus == 'approved';
    if (!isVerifiedCoach) {
      _showClientCoachPage();
      final hasSubmittedApplication =
          applicationStatus != null && applicationStatus.trim().isNotEmpty;
      if (autoOpen || !hasSubmittedApplication) return;

      final choice = await _chooseCoachPortal();
      if (!mounted || choice == null || choice == 'client') return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CoachApplicationStatusPage(
            initialStatus: applicationStatus,
            allowClose: true,
          ),
        ),
      );
      return;
    }

    if (autoOpen) {
      if (hasActiveCoachMembership) {
        _showExpertDashboard();
      } else {
        _showClientCoachPage();
        await _openCoachMembershipPaywall();
      }
      return;
    }

    final choice = await _chooseCoachPortal();

    if (!mounted || choice == null) return;
    if (choice == 'client') {
      _showClientCoachPage();
      return;
    }
    if (hasActiveCoachMembership) {
      _showExpertDashboard();
      return;
    }

    // Keep the client-facing module underneath the purchase route so closing
    // the paywall returns to a usable Coach tab instead of the previous tab.
    _showClientCoachPage();
    await _openCoachMembershipPaywall();
  }

  Future<String?> _chooseCoachPortal() {
    final t = AppLocalizations.of(context);
    return showTaqaOptionDialog<String>(
      context: context,
      title: t.translate("coach_portal_dialog_title"),
      options: [
        TaqaDialogOption(
          value: 'expert',
          title: t.translate("coach_portal_expert_title"),
          subtitle: t.translate("coach_portal_expert_sub"),
        ),
        TaqaDialogOption(
          value: 'client',
          title: t.translate("coach_portal_client_title"),
          subtitle: t.translate("coach_portal_client_sub"),
        ),
      ],
    );
  }

  void _showClientCoachPage() {
    if (!mounted) return;
    setState(() {
      _pages[MainLayout._coachTab] = const CoachPage(
        showBottomNavigation: false,
      );
      _index = MainLayout._coachTab;
    });
    _queuePostPurchaseIntro(
      MainLayout._coachTab,
      moduleOverride: TaqaIntroModule.clientCoach,
    );
  }

  void _showExpertDashboard() {
    if (!mounted) return;
    setState(() {
      _pages[MainLayout._coachTab] = const ExpertDashboardPage();
      _index = MainLayout._coachTab;
    });
    _queuePostPurchaseIntro(
      MainLayout._coachTab,
      moduleOverride: TaqaIntroModule.expertCoach,
    );
  }

  Future<void> _openCoachMembershipPaywall() async {
    if (!mounted) return;
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
    if (!mounted) return;
    if (subscribed == true) {
      // Checkout success already means the coach entitlement was verified.
      // Do not re-run the cached role/access checks here: those can still be
      // refreshing and would incorrectly leave the client Coach page open.
      final choice = await _chooseCoachPortal();
      if (!mounted) return;
      if (choice == 'expert') {
        _showExpertDashboard();
      } else if (choice == 'client') {
        _showClientCoachPage();
      }
      return;
    }
    if (_index == MainLayout._coachTab) {
      _queuePostPurchaseIntro(
        MainLayout._coachTab,
        moduleOverride: TaqaIntroModule.clientCoach,
      );
    }
  }

  Widget _buildBottomNav() {
    return TaqaBottomNavBar(
      currentIndex: _index,
      onTap: _selectTab,
      items: const [
        TaqaBottomNavItem(
          assetPath: 'assets/icons/Diet.svg',
          index: MainLayout._dietTab,
        ),
        TaqaBottomNavItem(
          assetPath: 'assets/icons/Exercise.svg',
          index: MainLayout._trainTab,
        ),
        TaqaBottomNavItem(
          assetPath: 'assets/icons/Home.svg',
          index: MainLayout._dashboardTab,
        ),
        TaqaBottomNavItem(
          assetPath: 'assets/icons/Community.svg',
          index: MainLayout._communityTab,
        ),
        TaqaBottomNavItem(
          assetPath: 'assets/icons/Trainer.svg',
          index: MainLayout._coachTab,
        ),
      ],
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case MainLayout._dietTab:
        return DietPage(key: _dietKey);
      case MainLayout._trainTab:
        return TrainPage(key: _trainKey);
      case MainLayout._dashboardTab:
        return DashboardPage(key: _dashboardKey, onNavigateToTab: _selectTab);
      case MainLayout._communityTab:
        return const CommunityPage();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Heavy-style persistent "minimized workout" bar shown above the bottom nav
/// whenever a workout session is active. It lives in the app shell so it
/// survives across tabs, and sits in the bottomNavigationBar slot so it is
/// always above the system (Android) nav bar. Renders nothing when idle.
class _MinimizedWorkoutBar extends StatefulWidget {
  const _MinimizedWorkoutBar({required this.onExpand, required this.onDiscard});

  final Future<void> Function() onExpand;
  final Future<void> Function() onDiscard;

  @override
  State<_MinimizedWorkoutBar> createState() => _MinimizedWorkoutBarState();
}

class _MinimizedWorkoutBarState extends State<_MinimizedWorkoutBar> {
  Map<String, dynamic>? _session;
  Timer? _ticker;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    AccountStorage.trainingChange.addListener(_reload);
    // Re-fetch the active session every second (cheap SharedPreferences read)
    // so the bar reliably appears/disappears even when no trainingChange event
    // fires (e.g. startSession isn't always followed by a notify).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      unawaited(_reload());
    });
    _reload();
  }

  @override
  void dispose() {
    AccountStorage.trainingChange.removeListener(_reload);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final session = await TrainingActivityService.getActiveSession();
    if (!mounted) return;
    // Only rebuild when presence/identity actually changes; the per-second
    // timer rebuild is driven by _recomputeElapsed instead.
    final wasActive = _session != null;
    final isActive = session != null;
    final nameChanged =
        (_session?['name'])?.toString() != (session?['name'])?.toString();
    if (wasActive != isActive || nameChanged) {
      setState(() => _session = session);
    } else {
      _session = session;
    }
    _recomputeElapsed();
  }

  void _recomputeElapsed() {
    final session = _session;
    if (session == null) {
      if (_elapsed != 0 && mounted) setState(() => _elapsed = 0);
      return;
    }
    final paused = session['paused'] == true;
    int next = _elapsed;
    if (paused) {
      final ps = session['pausedSeconds'];
      next = ps is int ? ps : (ps is num ? ps.toInt() : _elapsed);
    } else {
      final startMs = session['startMs'];
      if (startMs is int && startMs > 0) {
        next = ((DateTime.now().millisecondsSinceEpoch - startMs) / 1000)
            .floor();
      } else if (startMs is num && startMs > 0) {
        next =
            ((DateTime.now().millisecondsSinceEpoch - startMs.toInt()) / 1000)
                .floor();
      }
    }
    if (next < 0) next = 0;
    if (next != _elapsed && mounted) setState(() => _elapsed = next);
  }

  String _formatElapsed(int total) {
    final s = total < 0 ? 0 : total;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
    }
    if (m > 0) {
      return "${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
    }
    return "${sec}s";
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    final name = (session['name'] ?? '').toString().trim();

    return Material(
      color: const Color(0xFF1C1D17),
      child: InkWell(
        onTap: () => unawaited(widget.onExpand()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Workout  ${_formatElapsed(_elapsed)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Reopen workout",
                onPressed: () => unawaited(widget.onExpand()),
                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              ),
              IconButton(
                tooltip: "Discard workout",
                onPressed: () => unawaited(widget.onDiscard()),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
