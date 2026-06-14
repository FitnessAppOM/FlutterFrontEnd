import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import 'profile_info_section.dart';

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

    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        children: [
          ProfileInfoRow(
            label: t.translate("profile_main_goal"),
            value: mainGoal,
          ),
          ProfileInfoRow(
            label: t.translate("profile_workout_freq"),
            value: workoutFreq,
          ),
          ProfileInfoRow(
            label: t.translate("profile_diet_pref"),
            value: dietPref,
          ),
          ProfileInfoRow(
            label: t.translate("profile_experience"),
            value: experience,
          ),
        ],
      ),
    );
  }
}
