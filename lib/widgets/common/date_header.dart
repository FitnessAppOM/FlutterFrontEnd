import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../localization/app_localizations.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

class DateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime? todayReference;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final bool canGoNext;
  final String label;

  const DateHeader({
    super.key,
    required this.selectedDate,
    this.todayReference,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final t = AppLocalizations.of(context).translate;
    final locale = AppLocalizations.of(context).locale.languageCode;
    final dateLabel = DateFormat('EEEE, MMM d', locale).format(selectedDate);
    final reference = _dateOnly(todayReference ?? DateTime.now());
    final isToday = _dateOnly(selectedDate) == reference;
    final isYesterday =
        _dateOnly(selectedDate) == reference.subtract(const Duration(days: 1));
    final relative = isToday
        ? t("date_today")
        : isYesterday
        ? t("date_yesterday")
        : DateFormat('MMM d, y', locale).format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colors.textPrimary),
            onPressed: onPrev,
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d', locale).format(selectedDate),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM',
                          locale,
                        ).format(selectedDate).toUpperCase(),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        relative,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext
                  ? colors.textPrimary
                  : colors.textSecondary.withValues(alpha: 0.45),
            ),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
