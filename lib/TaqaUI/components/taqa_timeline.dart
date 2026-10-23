import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared all-day summary card for calendar and timeline experiences.
class TaqaTimelineSummaryCard extends StatelessWidget {
  const TaqaTimelineSummaryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(13),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: TaqaUiScale.radius(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          SizedBox(width: TaqaUiScale.w(11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: TaqaUiScale.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: TaqaUiScale.sp(13),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TaqaUiScale.sp(10),
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

/// Shared expandable event surface used inside an hourly timeline.
class TaqaTimelineEventCard extends StatelessWidget {
  const TaqaTimelineEventCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: TaqaUiScale.radius(12),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: TaqaUiScale.insetsLTRB(10, 2, 8, 2),
          childrenPadding: TaqaUiScale.insetsLTRB(12, 0, 12, 12),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: TaqaUiScale.radius(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TaqaUiScale.sp(10),
            ),
          ),
          children: [details],
        ),
      ),
    );
  }
}

/// Shared label/value row for expanded timeline details.
class TaqaTimelineDetailLine extends StatelessWidget {
  const TaqaTimelineDetailLine({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Padding(
      padding: EdgeInsets.only(top: TaqaUiScale.h(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: TaqaUiScale.w(8)),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TaqaUiScale.sp(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared 24-hour rail. Features supply already-composed event widgets while
/// TaqaUI owns spacing, hour markers, lines, borders and empty-hour treatment.
class TaqaHourlyTimeline extends StatelessWidget {
  const TaqaHourlyTimeline({
    super.key,
    required this.hourLabel,
    required this.eventsByHour,
  });

  final String Function(int hour) hourLabel;
  final Map<int, List<Widget>> eventsByHour;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: List.generate(24, (hour) {
          final events = eventsByHour[hour] ?? const <Widget>[];
          return _TaqaTimelineHourRow(
            hourLabel: hourLabel(hour),
            events: events,
            isLast: hour == 23,
          );
        }),
      ),
    );
  }
}

class _TaqaTimelineHourRow extends StatelessWidget {
  const _TaqaTimelineHourRow({
    required this.hourLabel,
    required this.events,
    required this.isLast,
  });

  final String hourLabel;
  final List<Widget> events;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final timeColumnWidth = TaqaUiScale.w(62);
    final railColumnWidth = TaqaUiScale.w(26);

    return Stack(
      children: [
        if (!isLast)
          PositionedDirectional(
            start: timeColumnWidth + (railColumnWidth / 2) - 0.5,
            top: TaqaUiScale.h(19),
            bottom: 0,
            child: Container(width: 1, color: colors.border),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: timeColumnWidth,
              child: Padding(
                padding: TaqaUiScale.insetsLTRB(8, 12, 4, 8),
                child: Text(
                  hourLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: events.isEmpty
                        ? colors.textSecondary.withValues(alpha: 0.72)
                        : colors.textPrimary,
                    fontSize: TaqaUiScale.sp(10),
                    fontWeight: events.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: railColumnWidth,
              child: Column(
                children: [
                  SizedBox(height: TaqaUiScale.h(15)),
                  Container(
                    width: events.isEmpty ? 6 : 9,
                    height: events.isEmpty ? 6 : 9,
                    decoration: BoxDecoration(
                      color: events.isEmpty ? colors.border : colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: TaqaUiScale.h(48)),
                padding: TaqaUiScale.insetsLTRB(4, 5, 10, 7),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(bottom: BorderSide(color: colors.border)),
                ),
                child: events.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: events
                            .map(
                              (event) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: TaqaUiScale.h(5),
                                ),
                                child: event,
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
