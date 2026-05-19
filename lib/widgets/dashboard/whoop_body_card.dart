import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';

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
    final value = linked
        ? (weightKg != null
            ? "${weightKg!.toStringAsFixed(1)} kg"
            : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked ? "Current weight" : "Connect Whoop";
    return TaqaProgressWidgetCard(
      title: "Whoop Body",
      valueText: value,
      goalText: subtitle,
      progress: 0.0,
      loading: loading && linked && weightKg == null,
      onTap: onTap,
    );
  }
}
