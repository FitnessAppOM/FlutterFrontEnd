import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class FitbitBodyCard extends StatelessWidget {
  final bool loading;
  final double? weightKg;
  final VoidCallback? onTap;

  const FitbitBodyCard({
    super.key,
    required this.loading,
    required this.weightKg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = loading
        ? "…"
        : weightKg != null
        ? "${weightKg!.toStringAsFixed(1)} kg"
        : "—";

    final t = AppLocalizations.of(context).translate;
    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.fitbit,
      title: t("fitbit_body_title"),
      valueText: value,
      goalText: t("fitbit_body_current_weight"),
      progress: 0.0,
      showArc: false,
      loading: loading && weightKg == null,
      onTap: onTap,
    );
  }
}
