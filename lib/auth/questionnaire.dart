import 'package:flutter/material.dart';

class QuestionnairePage extends StatelessWidget {
  const QuestionnairePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Questionnaire")),
      body: const Center(child: Text("Welcome to Questionnaire Page")),
    );
  }
}
