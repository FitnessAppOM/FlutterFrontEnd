import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/dashboard_page.dart';
import 'pages/train_page.dart';
import 'pages/diet_page.dart';
import 'pages/community_page.dart';
import 'pages/profile_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _index = 0;

  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey<DashboardPageState>();
  final GlobalKey<DietPageState> _dietKey = GlobalKey<DietPageState>();

  late final List<Widget> pages = [
    DashboardPage(key: _dashboardKey),
    const TrainPage(),
    DietPage(key: _dietKey),
    const CommunityPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _index,
        children: pages,
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
        setState(() => _index = idx);
        if (idx == 0) {
          _dashboardKey.currentState?.refreshExerciseProgress();
        }
        if (idx == 2) {
          _dietKey.currentState?.refreshTrainingLock();
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
}
