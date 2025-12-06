import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SectionHeader(title: "Dashboard"),
          SizedBox(height: 20),
          CardContainer(
            child: Text("Dashboard content here", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}