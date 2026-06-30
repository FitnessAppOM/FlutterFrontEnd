import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class WhoopBodyCard extends StatelessWidget {
  const WhoopBodyCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.weightKg,
    required this.onTap,
  });

  final bool loading;
  final bool linked;
  final double? weightKg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final value = linked
        ? (weightKg != null
              ? "${weightKg!.toStringAsFixed(1)} kg"
              : (loading ? "…" : "—"))
        : t("whoop_not_connected");
    final subtitle = linked
        ? t("fitbit_body_current_weight")
        : t("whoop_connect_title");
    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.whoop,
      title: t("whoop_body_title"),
      valueText: value,
      goalText: subtitle,
      progress: 0.0,
      loading: loading && linked && weightKg == null,
      onTap: onTap,
    );
  }
}
