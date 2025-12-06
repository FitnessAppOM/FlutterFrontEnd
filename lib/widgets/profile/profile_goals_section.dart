import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import 'section_title.dart';

class ProfileGoalsSection extends StatelessWidget {
  const ProfileGoalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(text: t.translate("profile_goals_title")),
        const SizedBox(height: 12),

        _goalTile(t.translate("profile_main_goal"), "—"),
        _goalTile(t.translate("profile_workout_freq"), "—"),
        _goalTile(t.translate("profile_diet_pref"), "—"),
      ],
    );
  }

  Widget _goalTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}