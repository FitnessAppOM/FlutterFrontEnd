import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'pages/train_page.dart';
import 'pages/diet_page.dart';
import 'pages/community_page.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../services/core/navigation_service.dart';
import '../services/screenings/screening_prompt_service.dart';
import '../services/training/training_activity_service.dart';
import '../screens/coach_page.dart';
import '../screens/expert_dashboard_page.dart';
import '../TaqaUI/components/taqa_bottom_nav_bar.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialIndex = _dashboardTab});

  static const int _dietTab = 0;
  static const int _trainTab = 1;
  static const int _dashboardTab = 2;
  static const int _communityTab = 3;
  static const int _coachTab = 4;

  final int initialIndex;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _index;

  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();
  final GlobalKey<DietPageState> _dietKey = GlobalKey<DietPageState>();
  final GlobalKey<TrainPageState> _trainKey = GlobalKey<TrainPageState>();

  late final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    _index = (idx >= 0 && idx < 5) ? idx : 0;
    _pages[_index] = _buildPage(_index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.setNotificationNavigationReady(true);
      NavigationService.flushPendingNotificationNavigation();
      ScreeningPromptService.checkAndPromptIfDue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkPage =
        _index == MainLayout._dietTab || _index == MainLayout._communityTab;
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

  Future<bool> _resolveIsExpert() async {
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return AccountStorage.isExpert();
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final filledExpertQuestionnaire =
          profile["filled_expert_questionnaire"] == true;
      final isExpert = profile["is_expert"] == true;
      await AccountStorage.setExpertQuestionnaireDone(
        filledExpertQuestionnaire,
      );
      await AccountStorage.setIsExpert(isExpert);
      return isExpert;
    } catch (_) {
      return AccountStorage.isExpert();
    }
  }

  Future<void> _openCoach() async {
    final isExpert = await _resolveIsExpert();
    if (!mounted) return;

    if (!isExpert) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CoachPage()));
      return;
    }

    final t = AppLocalizations.of(context);
    final choice = await showTaqaOptionDialog<String>(
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

    if (!mounted || choice == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => choice == 'expert'
            ? const ExpertDashboardPage()
            : const CoachPage(),
      ),
    );
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
  const _MinimizedWorkoutBar({
    required this.onExpand,
    required this.onDiscard,
  });

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
        next =
            ((DateTime.now().millisecondsSinceEpoch - startMs) / 1000).floor();
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
