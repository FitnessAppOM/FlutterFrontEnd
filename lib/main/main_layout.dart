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
      bottomNavigationBar: _buildBottomNav(),
    );
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
        return const TrainPage();
      case MainLayout._dashboardTab:
        return DashboardPage(key: _dashboardKey, onNavigateToTab: _selectTab);
      case MainLayout._communityTab:
        return const CommunityPage();
      default:
        return const SizedBox.shrink();
    }
  }
}
