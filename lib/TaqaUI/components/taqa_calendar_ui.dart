import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_filled_button.dart';

@immutable
class TaqaCalendarDayData {
  const TaqaCalendarDayData({
    required this.date,
    required this.inVisibleMonth,
    required this.selected,
    required this.today,
    required this.semanticsLabel,
    this.indicatorColors = const <Color>[],
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool selected;
  final bool today;
  final String semanticsLabel;
  final List<Color> indicatorColors;
}

/// Taqa-styled, data-agnostic month calendar.
///
/// Feature screens own dates and business state; this component owns all
/// calendar presentation, interaction affordances, and accessibility layout.
class TaqaCalendarMonthCard extends StatelessWidget {
  const TaqaCalendarMonthCard({
    super.key,
    required this.monthLabel,
    required this.weekdayLabels,
    required this.days,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
    required this.previousMonthTooltip,
    required this.nextMonthTooltip,
    required this.retryLabel,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final String monthLabel;
  final List<String> weekdayLabels;
  final List<TaqaCalendarDayData> days;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final ValueChanged<DateTime> onDayTap;
  final String previousMonthTooltip;
  final String nextMonthTooltip;
  final String retryLabel;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      padding: TaqaUiScale.insetsLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _TaqaCalendarMonthHeader(
            monthLabel: monthLabel,
            previousMonthTooltip: previousMonthTooltip,
            nextMonthTooltip: nextMonthTooltip,
            onPreviousMonth: loading ? null : onPreviousMonth,
            onNextMonth: loading ? null : onNextMonth,
          ),
          Divider(height: TaqaUiScale.h(14), color: colors.divider),
          if (loading)
            SizedBox(
              height: TaqaUiScale.h(258),
              child: Center(
                child: SizedBox.square(
                  dimension: TaqaUiScale.w(24),
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else if (error != null)
            SizedBox(
              height: TaqaUiScale.h(258),
              child: Center(
                child: Padding(
                  padding: TaqaUiScale.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: TaqaUiScale.w(36),
                        height: TaqaUiScale.w(36),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          color: colors.textSecondary,
                          size: TaqaUiScale.w(18),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: colors.textSecondary,
                          fontSize: TaqaUiScale.sp(12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(8)),
                      TextButton(onPressed: onRetry, child: Text(retryLabel)),
                    ],
                  ),
                ),
              ),
            )
          else
            _TaqaCalendarGrid(
              weekdayLabels: weekdayLabels,
              days: days,
              onDayTap: onDayTap,
            ),
        ],
      ),
    );
  }
}

class _TaqaCalendarMonthHeader extends StatelessWidget {
  const _TaqaCalendarMonthHeader({
    required this.monthLabel,
    required this.previousMonthTooltip,
    required this.nextMonthTooltip,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String monthLabel;
  final String previousMonthTooltip;
  final String nextMonthTooltip;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Row(
      children: [
        _TaqaCalendarArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: previousMonthTooltip,
          onTap: onPreviousMonth,
        ),
        Expanded(
          child: Text(
            monthLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(18),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        _TaqaCalendarArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: nextMonthTooltip,
          onTap: onNextMonth,
        ),
      ],
    );
  }
}

class _TaqaCalendarArrowButton extends StatelessWidget {
  const _TaqaCalendarArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceElevated,
        disabledBackgroundColor: colors.surfaceElevated.withValues(alpha: .5),
        minimumSize: Size.square(TaqaUiScale.w(36)),
        maximumSize: Size.square(TaqaUiScale.w(36)),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: TaqaUiScale.w(20)),
      color: colors.textPrimary,
      disabledColor: colors.textSecondary.withValues(alpha: .45),
    );
  }
}

class _TaqaCalendarGrid extends StatelessWidget {
  const _TaqaCalendarGrid({
    required this.weekdayLabels,
    required this.days,
    required this.onDayTap,
  });

  final List<String> weekdayLabels;
  final List<TaqaCalendarDayData> days;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final cellHeight =
        (MediaQuery.textScalerOf(context).scale(TaqaUiScale.sp(12)) * 1.5 + 22)
            .clamp(48.0, 120.0);
    return Column(
      children: [
        Row(
          children: weekdayLabels
              .take(7)
              .map(
                (label) => Expanded(
                  child: Text(
                    taqaUppercase(label),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                      color: colors.textSecondary,
                      fontSize: TaqaUiScale.sp(8),
                      fontWeight: FontWeight.w400,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: TaqaUiScale.h(8)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: cellHeight,
          ),
          itemBuilder: (context, index) => _TaqaCalendarDayCell(
            day: days[index],
            onTap: () => onDayTap(days[index].date),
          ),
        ),
      ],
    );
  }
}

class _TaqaCalendarDayCell extends StatelessWidget {
  const _TaqaCalendarDayCell({required this.day, required this.onTap});

  final TaqaCalendarDayData day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Semantics(
      button: true,
      selected: day.selected,
      onTap: onTap,
      label: day.semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: TaqaUiScale.radius(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: day.selected ? colors.accent : Colors.transparent,
              borderRadius: TaqaUiScale.radius(12),
              border: day.today && !day.selected
                  ? Border.all(color: colors.accent, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.date.day}',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: day.selected
                          ? colors.onAccent
                          : day.inVisibleMonth
                          ? colors.textPrimary
                          : colors.textSecondary.withValues(alpha: .32),
                      fontSize: TaqaUiScale.sp(12),
                      fontWeight: day.today || day.selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(4)),
                SizedBox(
                  height: TaqaUiScale.h(5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: day.indicatorColors
                        .take(6)
                        .map(
                          (color) => Container(
                            width: TaqaUiScale.w(3.5),
                            height: TaqaUiScale.w(3.5),
                            margin: const EdgeInsets.symmetric(horizontal: .7),
                            decoration: BoxDecoration(
                              color: day.selected ? colors.onAccent : color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class TaqaCalendarLegendItem {
  const TaqaCalendarLegendItem({required this.color, required this.label});

  final Color color;
  final String label;
}

class TaqaCalendarLegend extends StatelessWidget {
  const TaqaCalendarLegend({super.key, required this.items});

  final List<TaqaCalendarLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Wrap(
      spacing: TaqaUiScale.w(8),
      runSpacing: TaqaUiScale.h(8),
      children: items
          .map(
            (item) => Container(
              padding: TaqaUiScale.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: TaqaUiScale.radius(999),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: TaqaUiScale.w(7),
                    height: TaqaUiScale.w(7),
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(5)),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: colors.textSecondary,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class TaqaCalendarSummaryItem {
  const TaqaCalendarSummaryItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.iconWidget,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? iconWidget;
}

class TaqaCalendarDaySummaryCard extends StatelessWidget {
  const TaqaCalendarDaySummaryCard({
    super.key,
    required this.dateLabel,
    required this.items,
    required this.emptyLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final String dateLabel;
  final List<TaqaCalendarSummaryItem> items;
  final String emptyLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: TaqaUiScale.h(14)),
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: colors.textSecondary,
                  fontSize: TaqaUiScale.sp(12),
                ),
              ),
            )
          else
            ...items.map((item) => _TaqaCalendarSummaryRow(item: item)),
          SizedBox(height: TaqaUiScale.h(10)),
          TaqaFilledButton(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

class _TaqaCalendarSummaryRow extends StatelessWidget {
  const _TaqaCalendarSummaryRow({required this.item});

  final TaqaCalendarSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
      child: Row(
        children: [
          Container(
            width: TaqaUiScale.w(38),
            height: TaqaUiScale.w(38),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: .14),
              borderRadius: TaqaUiScale.radius(10),
            ),
            child: Center(
              child:
                  item.iconWidget ??
                  Icon(item.icon, color: item.color, size: 19),
            ),
          ),
          SizedBox(width: TaqaUiScale.w(11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    color: colors.textSecondary,
                    fontSize: TaqaUiScale.sp(11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
