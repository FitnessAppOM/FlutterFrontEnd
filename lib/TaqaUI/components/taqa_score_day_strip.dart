import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_score_arc_card.dart';

/// A single day's value for [TaqaScoreDayStrip].
class TaqaScoreDayItem {
  const TaqaScoreDayItem({
    required this.date,
    required this.score,
    this.valueDisplay,
  });

  final DateTime date;
  final double? score;
  final String? valueDisplay;
}

/// Row of same-style arc cards for the most recent days (e.g. the last 3),
/// the same "arc + day label" tile used on the Taqa Score detail page, just
/// laid out side by side instead of one-per-page. The last item is treated
/// as the currently selected day and shown at full emphasis.
class TaqaScoreDayStrip extends StatelessWidget {
  const TaqaScoreDayStrip({
    super.key,
    required this.items,
    this.maxScore = 100,
  });

  final List<TaqaScoreDayItem> items;
  final double maxScore;

  @override
  Widget build(BuildContext context) {
    final lastIndex = items.length - 1;
    final cardSize = items.length <= 2
        ? TaqaUiScale.w(150)
        : TaqaUiScale.w(108);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < items.length; i++)
          Opacity(
            opacity: i == lastIndex ? 1 : 0.6,
            child: Column(
              children: [
                Text(
                  _dayLabel(items[i].date, isSelected: i == lastIndex),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                    fontSize: TaqaUiScale.sp(9),
                    fontWeight: FontWeight.w400,
                    color: TaqaUiColors.charcoal,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(8)),
                TaqaScoreArcCard(
                  score: items[i].score,
                  maxScore: maxScore,
                  valueDisplay: items[i].valueDisplay,
                  size: i == lastIndex ? cardSize : cardSize * 0.86,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _dayLabel(DateTime date, {required bool isSelected}) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(date.year, date.month, date.day);
    final diff = todayOnly.difference(dayOnly).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return _weekdayName(date.weekday).toUpperCase();
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }
}
