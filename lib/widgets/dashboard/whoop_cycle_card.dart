import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';
import '../../localization/app_localizations.dart';

class WhoopCycleCard extends StatelessWidget {
  const WhoopCycleCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.strain,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final double? strain;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final progress = linked && strain != null
        ? (strain! / 21.0).clamp(0.0, 1.0)
        : 0.0;
    final value = linked
        ? (strain != null ? _fmt(strain) : (loading ? "…" : "—"))
        : t("whoop_not_connected");
    final subtitle = linked
        ? (strain != null
              ? t("whoop_cycle_out_of_21")
              : t("whoop_cycle_no_data"))
        : t("whoop_connect_title");
    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.whoop,
      title: t("whoop_daily_strain_title"),
      valueText: value,
      goalText: subtitle,
      progress: progress,
      showArc: true,
      loading: loading && linked && strain == null,
      onTap: onTap,
    );
  }

  String _fmt(double? v) {
    if (v == null) return "—";
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
