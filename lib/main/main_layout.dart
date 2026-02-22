import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'pages/train_page.dart';
import 'pages/diet_page.dart';
import 'pages/community_page.dart';
import 'pages/profile_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _index;

  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey<DashboardPageState>();
  final GlobalKey<DietPageState> _dietKey = GlobalKey<DietPageState>();

  late final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    _index = (idx >= 0 && idx < 5) ? idx : 0;
    _pages[_index] = _buildPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _index,
        children: List.generate(
          5,
          (i) => _pages[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(Icons.dashboard, 0),
          _item(Icons.fitness_center, 1),
          _item(Icons.restaurant_menu, 2),
          _item(Icons.people_alt, 3),
          _item(Icons.person, 4),
        ],
      ),
    );
  }

  Widget _item(IconData icon, int idx) {
    final selected = idx == _index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _index = idx;
          _pages[idx] ??= _buildPage(idx);
        });
        if (idx == 2) {
          _dietKey.currentState?.refreshTrainingLock();
          // Refetch targets and day summary so surplus from calories burned shows without manual refresh.
          _dietKey.currentState?.refreshTargetsAndMeals();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: selected ? 30 : 26,
          color: selected ? AppColors.accent : Colors.white,
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardPage(key: _dashboardKey);
      case 1:
        return const TrainPage();
      case 2:
        return DietPage(key: _dietKey);
      case 3:
        return const CommunityPage();
      case 4:
      default:
        return const ProfilePage();
    }
  }
}
