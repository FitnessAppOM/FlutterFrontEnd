import 'package:flutter/material.dart';

import 'taqa_progress_widget_card.dart';
import '../styles/taqa_ui_scale.dart';

enum TaqaDashboardMetricSource { fitbit, whoop, strava }

class TaqaDashboardMetricCard extends StatelessWidget {
  const TaqaDashboardMetricCard({
    super.key,
    required this.source,
    required this.title,
    required this.valueText,
    required this.goalText,
    required this.progress,
    this.showArc = true,
    this.showSourceLogo = true,
    this.showArrow = true,
    this.loading = false,
    this.onTap,
  });

  final TaqaDashboardMetricSource source;
  final String title;
  final String valueText;
  final String goalText;
  final double progress;
  final bool showArc;
  final bool showSourceLogo;
  final bool showArrow;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logoPath = switch (source) {
      TaqaDashboardMetricSource.fitbit => 'assets/images/fitbit.png',
      TaqaDashboardMetricSource.whoop => 'assets/images/whoop.png',
      TaqaDashboardMetricSource.strava =>
        'assets/images/strava_logo_icon_170697.png',
    };

    return TaqaProgressWidgetCard(
      title: title,
      valueText: valueText,
      goalText: goalText,
      progress: progress,
      showArc: showArc,
      loading: loading,
      onTap: onTap,
      topRight: showSourceLogo
          ? Image.asset(
              logoPath,
              width: TaqaUiScale.w(14),
              height: TaqaUiScale.h(14),
              fit: BoxFit.contain,
              color: Colors.black,
              colorBlendMode: BlendMode.srcIn,
            )
          : (showArrow ? null : const SizedBox.shrink()),
    );
  }
}
