import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'pages/train_page.dart';
import 'pages/diet_page.dart';
import 'pages/community_page.dart';
import 'pages/profile_page.dart';
import '../core/account_storage.dart';
import '../services/auth/profile_service.dart';
import '../services/core/navigation_service.dart';
import '../services/screenings/screening_prompt_service.dart';
import '../TaqaUI/components/taqa_bottom_nav_bar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialIndex = _dashboardTab});

  static const int _dietTab = 0;
  static const int _trainTab = 1;
  static const int _dashboardTab = 2;
  static const int _communityTab = 3;
  static const int _profileTab = 4;

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
    if (idx == MainLayout._profileTab) {
      _preloadExpertFlagsForProfileTab();
    }
  }

  Future<void> _preloadExpertFlagsForProfileTab() async {
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final filledExpertQuestionnaire =
          profile["filled_expert_questionnaire"] == true;

      final done = filledExpertQuestionnaire;
      final isExpert = profile["is_expert"] == true;

      await AccountStorage.setExpertQuestionnaireDone(done);
      await AccountStorage.setIsExpert(isExpert);
    } catch (_) {
      // Best-effort preload only.
    }
  }

  Widget _buildBottomNav() {
    return TaqaBottomNavBar(
      currentIndex: _index,
      onTap: _selectTab,
      items: const [
        TaqaBottomNavItem(
          icon: Icons.restaurant_menu,
          index: MainLayout._dietTab,
        ),
        TaqaBottomNavItem(
          icon: Icons.fitness_center,
          index: MainLayout._trainTab,
        ),
        TaqaBottomNavItem(
          icon: Icons.dashboard,
          index: MainLayout._dashboardTab,
        ),
        TaqaBottomNavItem(
          icon: Icons.people_alt,
          index: MainLayout._communityTab,
        ),
        TaqaBottomNavItem(
          icon: Icons.person,
          index: MainLayout._profileTab,
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
      case MainLayout._profileTab:
      default:
        return const ProfilePage();
    }
  }
}
