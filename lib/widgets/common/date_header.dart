import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

class DateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final bool canGoNext;
  final String label;

  const DateHeader({
    super.key,
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final locale = AppLocalizations.of(context).locale.languageCode;
    final dateLabel = DateFormat('EEEE, MMM d', locale).format(selectedDate);
    final isToday = _isToday(selectedDate);
    final isYesterday = _isToday(selectedDate.subtract(const Duration(days: 1)));
    final relative = isToday
        ? t("date_today")
        : isYesterday
            ? t("date_yesterday")
            : DateFormat('MMM d, y', locale).format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1F27), Color(0xFF13151C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: onPrev,
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d', locale).format(selectedDate),
                        style: AppTextStyles.title.copyWith(color: Colors.white),
                      ),
                      Text(
                        DateFormat('MMM', locale).format(selectedDate).toUpperCase(),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.textDim,
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
                      style: AppTextStyles.small.copyWith(color: AppColors.textDim),
                    ),
                    const SizedBox(height: 4),
                    Text(dateLabel, style: AppTextStyles.subtitle),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        relative,
                        style: AppTextStyles.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}
