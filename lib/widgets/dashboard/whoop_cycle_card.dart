import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_dashboard_metric_card.dart';

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
    final progress = linked && strain != null
        ? (strain! / 21.0).clamp(0.0, 1.0)
        : 0.0;
    final value = linked
        ? (strain != null ? _fmt(strain) : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked
        ? (strain != null ? "Out of 21" : "No cycle data yet")
        : "Connect Whoop";
    return TaqaDashboardMetricCard(
      source: TaqaDashboardMetricSource.whoop,
      title: "Whoop Daily Strain",
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
