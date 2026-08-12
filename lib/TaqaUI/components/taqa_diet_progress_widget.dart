import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../localization/app_localizations.dart';
import 'taqa_progress_widget_card.dart';

class TaqaDietProgressWidget extends StatelessWidget {
  const TaqaDietProgressWidget({
    super.key,
    required this.loading,
    required this.consumedCalories,
    required this.targetCalories,
    this.onTap,
  });

  final bool loading;
  final int? consumedCalories;
  final int? targetCalories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final numberFormat = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final consumed = consumedCalories ?? 0;
    final target = targetCalories ?? 0;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final targetText = target > 0
        ? '${numberFormat.format(target)} ${t("diet_kcal_label")}'
        : t('diet_progress_no_target');

    return TaqaProgressWidgetCard(
      title: t('diet_progress_title'),
      valueText: numberFormat.format(consumed),
      goalText: loading ? t('common_loading') : targetText,
      progress: progress,
      loading: loading,
      lightSurface: false,
      onTap: onTap,
    );
  }
}
