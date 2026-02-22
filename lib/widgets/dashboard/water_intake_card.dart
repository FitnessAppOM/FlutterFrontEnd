import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class WaterIntakeCard extends StatelessWidget {
  final bool loading;
  final double intakeLiters;
  final double goalLiters;
  final int? deltaPercent;
  final VoidCallback? onTap;

  const WaterIntakeCard({
    super.key,
    required this.loading,
    required this.intakeLiters,
    required this.goalLiters,
    this.deltaPercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = loading ? "…" : "${intakeLiters.toStringAsFixed(1)} L";
    final subtitle = loading ? "" : "Goal ${goalLiters.toStringAsFixed(1)} L";

    return StatCard(
      title: "Water intake",
      value: value,
      subtitle: subtitle,
      icon: Icons.water_drop,
      accentColor: const Color(0xFF00BFA6),
      deltaPercent: deltaPercent,
      onTap: onTap,
    );
  }
}
