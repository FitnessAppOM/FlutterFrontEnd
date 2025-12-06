import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import 'section_title.dart';

class ProfileGoalsSection extends StatelessWidget {
  const ProfileGoalsSection({
    super.key,
    required this.mainGoal,
    required this.workoutFreq,
    required this.dietPref,
    required this.experience,
  });

  final String mainGoal;
  final String workoutFreq;
  final String dietPref;
  final String experience;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(text: t.translate("profile_goals_title")),
        const SizedBox(height: 12),

        _goalTile(t.translate("profile_main_goal"), mainGoal),
        _goalTile(t.translate("profile_workout_freq"), workoutFreq),
        _goalTile(t.translate("profile_diet_pref"), dietPref),
        _goalTile(t.translate("profile_experience"), experience),
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
