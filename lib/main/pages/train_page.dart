import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';

class TrainPage extends StatelessWidget {
  const TrainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SectionHeader(title: "Training"),
          SizedBox(height: 20),
          CardContainer(
            child: Text(
              "Training content goes here.",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}