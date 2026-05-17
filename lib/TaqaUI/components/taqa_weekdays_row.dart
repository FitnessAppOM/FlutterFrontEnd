import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import 'taqa_weekday_dot.dart';

class TaqaWeekdaysRow extends StatelessWidget {
  const TaqaWeekdaysRow({
    super.key,
    required this.currentWeekday,
    this.dotSize = TaqaUiStyles.weekdayDotSize,
  });

  final int currentWeekday; // DateTime weekday: Monday=1 .. Sunday=7
  final double dotSize;

  static const List<String> _labels = [
    'MON',
    'TUES',
    'WED',
    'THURS',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final responsiveDotSize = width < 320 ? 24.0 : dotSize;
        return Row(
          children: List.generate(_labels.length, (index) {
            final day = index + 1;
            return Expanded(
              child: Center(
                child: TaqaWeekdayDot(
                  label: _labels[index],
                  status: day < currentWeekday
                      ? TaqaWeekdayStatus.past
                      : day == currentWeekday
                      ? TaqaWeekdayStatus.current
                      : TaqaWeekdayStatus.future,
                  size: responsiveDotSize,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
