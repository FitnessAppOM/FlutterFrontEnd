import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import 'taqa_weekday_dot.dart';

class TaqaWeekdaysRow extends StatefulWidget {
  const TaqaWeekdaysRow({
    super.key,
    required this.selectedDate,
    required this.todayReference,
    this.dotSize = TaqaUiStyles.weekdayDotSize,
    this.maxPastWeeks = 26,
    this.onDateTap,
  });

  final DateTime selectedDate;
  final DateTime todayReference;
  final double dotSize;
  final int maxPastWeeks;
  final ValueChanged<DateTime>? onDateTap;

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
  State<TaqaWeekdaysRow> createState() => _TaqaWeekdaysRowState();
}

class _TaqaWeekdaysRowState extends State<TaqaWeekdaysRow> {
  late PageController _pageController;
  int _lastInitialPage = 0;

  static DateTime _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _weekStart(DateTime date) {
    final day = _dayKey(date);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  ({DateTime earliestWeekStart, int totalWeeks, int selectedPage})
  _weekWindow() {
    final safePastWeeks = widget.maxPastWeeks < 1 ? 1 : widget.maxPastWeeks;
    final today = _dayKey(widget.todayReference);
    final selected = _dayKey(widget.selectedDate);
    final currentWeekStart = _weekStart(today);
    final earliestWeekStart = currentWeekStart.subtract(
      Duration(days: (safePastWeeks - 1) * 7),
    );
    final minSelected = selected.isBefore(earliestWeekStart)
        ? earliestWeekStart
        : selected;
    final maxSelected = minSelected.isAfter(today) ? today : minSelected;
    final selectedWeekStart = _weekStart(maxSelected);
    final selectedPage =
        selectedWeekStart.difference(earliestWeekStart).inDays ~/ 7;
    return (
      earliestWeekStart: earliestWeekStart,
      totalWeeks: safePastWeeks,
      selectedPage: selectedPage,
    );
  }

  @override
  void initState() {
    super.initState();
    final window = _weekWindow();
    _lastInitialPage = window.selectedPage;
    _pageController = PageController(initialPage: _lastInitialPage);
  }

  @override
  void didUpdateWidget(covariant TaqaWeekdaysRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final window = _weekWindow();
    if (window.selectedPage != _lastInitialPage && _pageController.hasClients) {
      _pageController.jumpToPage(window.selectedPage);
    }
    _lastInitialPage = window.selectedPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = _weekWindow();
    final selected = _dayKey(widget.selectedDate);
    final today = _dayKey(widget.todayReference);

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveDotSize = constraints.maxWidth < 320
            ? 24.0
            : widget.dotSize;
        return SizedBox(
          height: responsiveDotSize + 20,
          child: PageView.builder(
            controller: _pageController,
            itemCount: window.totalWeeks,
            itemBuilder: (context, pageIndex) {
              final totalDotsWidth = responsiveDotSize * 7;
              final availableGapSpace =
                  (constraints.maxWidth - totalDotsWidth).clamp(0.0, 120.0);
              final gap = availableGapSpace / 6;
              final pageWeekStart = window.earliestWeekStart.add(
                Duration(days: pageIndex * 7),
              );
              return Row(
                children: List.generate(7, (dayOffset) {
                  final dayDate = pageWeekStart.add(Duration(days: dayOffset));
                  final isSelected = dayDate == selected;
                  final isFuture = dayDate.isAfter(today);
                  final status = isSelected
                      ? TaqaWeekdayStatus.current
                      : (isFuture
                            ? TaqaWeekdayStatus.future
                            : TaqaWeekdayStatus.past);
                  final dot = TaqaWeekdayDot(
                    label: TaqaWeekdaysRow._labels[dayDate.weekday - 1],
                    status: status,
                    size: responsiveDotSize,
                    onTap: isFuture || widget.onDateTap == null
                        ? null
                        : () => widget.onDateTap!(dayDate),
                  );
                  if (dayOffset == 6) return dot;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [dot, SizedBox(width: gap)],
                  );
                }),
              );
            },
          ),
        );
      },
    );
  }
}
