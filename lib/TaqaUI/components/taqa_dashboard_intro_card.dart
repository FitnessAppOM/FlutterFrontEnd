import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_layout.dart';
import '../styles/taqa_ui_styles.dart';
import 'taqa_intro_actions_row.dart';
import 'taqa_profile_avatar.dart';
import 'taqa_weekdays_row.dart';

class TaqaDashboardIntroCard extends StatelessWidget {
  const TaqaDashboardIntroCard({
    super.key,
    required this.userName,
    required this.profilePicture,
    required this.selectedDate,
    required this.todayReference,
    this.onDateTap,
    this.onTrainingTap,
    this.onDietTap,
    this.message =
        'Get ready and start logging your workouts and caloric intake for the week',
  });

  final String userName;
  final Widget profilePicture;
  final DateTime selectedDate;
  final DateTime todayReference;
  final ValueChanged<DateTime>? onDateTap;
  final VoidCallback? onTrainingTap;
  final VoidCallback? onDietTap;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cleanName = userName.trim().isEmpty ? 'Athlete' : userName.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            height: TaqaUiStyles.mainCardHeight,
            child: Container(
              padding: TaqaUiLayout.introCardContentPadding,
              decoration: const BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiStyles.cardRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TaqaProfileAvatar(child: profilePicture),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$cleanName,',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TaqaUiStyles.userName,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TaqaUiStyles.subtitle,
                  ),
                  const SizedBox(height: 9),
                  TaqaWeekdaysRow(
                    selectedDate: selectedDate,
                    todayReference: todayReference,
                    onDateTap: onDateTap,
                  ),
                  const Spacer(),
                  TaqaIntroActionsRow(
                    onTrainingTap: onTrainingTap,
                    onDietTap: onDietTap,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
