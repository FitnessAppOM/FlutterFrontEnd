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

  final pages = const [
    DashboardPage(),
    TrainPage(),
    DietPage(),
    CommunityPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_index],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
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