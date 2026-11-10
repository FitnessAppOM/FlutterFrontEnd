import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../taqa_ui_colors.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import 'taqa_adaptive_name_text.dart';
import 'taqa_intro_actions_row.dart';
import 'taqa_profile_avatar.dart';
import 'taqa_streak_tag.dart';
import 'taqa_weekdays_row.dart';
import 'taqa_pressable.dart';
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
    this.onCalendarTap,
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
  final VoidCallback? onCalendarTap;
  final String? message;
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final colors = context.taqaColors;
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
        // Leave room for the weekday text when system text size is increased.
        final weekdaysHeight =
            weekdayDotSize +
            TaqaUiScale.h(8) +
            MediaQuery.textScalerOf(
                  context,
                ).scale(TaqaUiStyles.weekdayLabel.fontSize ?? 8) *
                1.5 +
            1;
        final buttonsTop = TaqaUiScale.h(172) * layoutScale;
        final buttonRowWidth = TaqaUiScale.w(329) * layoutScale;
        final buttonHeight = TaqaUiStyles.actionButtonHeight * layoutScale;
        final streakTagGap = TaqaUiScale.w(8) * layoutScale;
        final calendarWidth = math.min(
          cardWidth * .42,
          TaqaUiScale.w(112) * layoutScale,
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: TaqaUiStyles.introCardRadius,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: leftInset,
                    top: avatarTop,
                    child: TaqaPressable(
                      onTap: onAvatarTap,
                      pressedScale: 0.92,
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
                    child: TaqaPressable(
                      onTap: onAvatarTap,
                      behavior: HitTestBehavior.opaque,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TaqaAdaptiveNameText(
                                  welcomeText: cleanName,
                                  userNameText: cleanName,
                                  style: TaqaUiStyles.userName.copyWith(
                                    color: colors.textPrimary,
                                  ),
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
                  ),
                  Positioned(
                    left: leftInset,
                    top: descriptionTop,
                    width: math.min(
                      descriptionWidth,
                      cardWidth -
                          (leftInset * 2) -
                          calendarWidth -
                          TaqaUiScale.w(8),
                    ),
                    height: descriptionHeight,
                    child: Text(
                      resolvedMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.subtitle.copyWith(
                        color: colors.textSecondary,
                        fontSize:
                            (TaqaUiStyles.subtitle.fontSize ?? 15) *
                            layoutScale,
                      ),
                    ),
                  ),
                  Positioned(
                    right: leftInset,
                    top: nameTop + nameHeight,
                    width: calendarWidth,
                    child: TextButton(
                      onPressed: onCalendarTap,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        disabledForegroundColor: colors.textSecondary,
                        minimumSize: const Size(0, 48),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(left: 6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                t('training_calendar'),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: TaqaUiScale.sp(11) * layoutScale,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
