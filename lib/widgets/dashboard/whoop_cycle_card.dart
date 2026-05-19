import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';

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
    final value = linked
        ? (strain != null ? _fmt(strain) : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked
        ? (strain != null ? "" : "No cycle data yet")
        : "Connect Whoop";
    return TaqaProgressWidgetCard(
      title: "Whoop Daily Cycle",
      valueText: value,
      goalText: subtitle,
      progress: 0.0,
      showArc: false,
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
