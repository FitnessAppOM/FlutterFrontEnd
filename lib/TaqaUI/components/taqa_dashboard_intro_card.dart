import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import 'taqa_intro_actions_row.dart';
import 'taqa_profile_avatar.dart';
import 'taqa_streak_tag.dart';
import 'taqa_weekdays_row.dart';
import '../../localization/app_localizations.dart';

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
    this.onAvatarTap,
    this.message,
    this.streakDays,
  });

  final String userName;
  final Widget profilePicture;
  final DateTime selectedDate;
  final DateTime todayReference;
  final ValueChanged<DateTime>? onDateTap;
  final VoidCallback? onTrainingTap;
  final VoidCallback? onDietTap;
  final VoidCallback? onAvatarTap;
  final String? message;
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final cleanName = userName.trim().isEmpty
        ? t('dash_athlete')
        : _capitalizeWords(userName.trim());
    final resolvedMessage = message ?? t('dash_intro_message');

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.mainCardWidth,
        );
        final cardHeight = TaqaUiStyles.mainCardHeight;
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.mainCardWidth,
        );
        final leftInset = TaqaUiScale.w(14) * layoutScale;
        final avatarTop = TaqaUiScale.h(15) * layoutScale;
        final avatarSize = TaqaUiStyles.avatarSize * layoutScale;
        final nameLeft = TaqaUiScale.w(59) * layoutScale;
        final nameTop = TaqaUiScale.h(18) * layoutScale;
        final nameHeight = TaqaUiScale.h(30) * layoutScale;
        final descriptionTop = TaqaUiScale.h(60) * layoutScale;
        final descriptionWidth =
            TaqaUiStyles.introDescriptionWidth * layoutScale;
        final weekdaysTop = TaqaUiScale.h(107) * layoutScale;
        final descriptionBottomGap = TaqaUiScale.h(10) * layoutScale;
        final descriptionHeight = math.max(
          TaqaUiScale.h(37) * layoutScale,
          weekdaysTop - descriptionTop - descriptionBottomGap,
        );
        final weekdaysWidth = TaqaUiStyles.weekdayTrackWidth * layoutScale;
        final weekdayDotSize = TaqaUiStyles.weekdayDotSize * layoutScale;
        final weekdaysHeight =
            weekdayDotSize + (TaqaUiScale.h(20) * layoutScale);
        final buttonsTop = TaqaUiScale.h(172) * layoutScale;
        final buttonRowWidth = TaqaUiScale.w(329) * layoutScale;
        final buttonHeight = TaqaUiStyles.actionButtonHeight * layoutScale;
        final streakTagGap = TaqaUiScale.w(8) * layoutScale;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiStyles.introCardRadius,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: leftInset,
                    top: avatarTop,
                    child: GestureDetector(
                      onTap: onAvatarTap,
                      child: TaqaProfileAvatar(
                        size: avatarSize,
                        child: profilePicture,
                      ),
                    ),
                  ),
                  Positioned(
                    left: nameLeft,
                    top: nameTop,
                    width: math.max(0, cardWidth - nameLeft - leftInset),
                    height: nameHeight,
                    child: GestureDetector(
                      onTap: onAvatarTap,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$cleanName,',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: TaqaUiStyles.userName,
                              ),
                            ),
                          ),
                          if (streakDays != null) ...[
                            SizedBox(width: streakTagGap),
                            TaqaStreakTag(days: streakDays!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: leftInset,
                    top: descriptionTop,
                    width: math.min(
                      descriptionWidth,
                      cardWidth - (leftInset * 2),
                    ),
                    height: descriptionHeight,
                    child: Text(
                      resolvedMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.subtitle.copyWith(
                        fontSize:
                            (TaqaUiStyles.subtitle.fontSize ?? 15) *
                            layoutScale,
                      ),
                    ),
                  ),
                  Positioned(
                    left: leftInset,
                    top: weekdaysTop,
                    width: math.min(weekdaysWidth, cardWidth - (leftInset * 2)),
                    height: weekdaysHeight,
                    child: TaqaWeekdaysRow(
                      selectedDate: selectedDate,
                      todayReference: todayReference,
                      dotSize: weekdayDotSize,
                      onDateTap: onDateTap,
                    ),
                  ),
                  Positioned(
                    left: leftInset,
                    top: buttonsTop,
                    width: math.min(
                      buttonRowWidth,
                      cardWidth - (leftInset * 2),
                    ),
                    height: buttonHeight,
                    child: TaqaIntroActionsRow(
                      onTrainingTap: onTrainingTap,
                      onDietTap: onDietTap,
                      buttonHeight: buttonHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _capitalizeWords(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }
}
