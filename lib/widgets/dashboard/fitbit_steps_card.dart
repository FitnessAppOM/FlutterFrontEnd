import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class FitbitStepsCard extends StatelessWidget {
  final bool loading;
  final int? steps;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FitbitStepsCard({
    super.key,
    required this.loading,
    required this.steps,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final value = steps != null ? "$steps" : (loading ? "…" : "0");

    return GestureDetector(
      onLongPress: onLongPress,
      child: TaqaDashboardMetricCard(
        source: TaqaDashboardMetricSource.fitbit,
        title: AppLocalizations.of(context).translate("fitbit_steps_title"),
        valueText: value,
        goalText: subtitle,
        progress: 0.0,
        showArc: false,
        loading: loading && steps == null,
        onTap: onTap,
      ),
    );
  }
}
