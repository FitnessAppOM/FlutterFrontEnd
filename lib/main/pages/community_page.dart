import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SectionHeader(title: "Community"),
          SizedBox(height: 20),
          CardContainer(
            child: Text(
              "Community content goes here.",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}