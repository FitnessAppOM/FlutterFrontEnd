import 'package:flutter/material.dart';

import 'stat_card.dart';

class HealthRecoveryLoadCard extends StatelessWidget {
  const HealthRecoveryLoadCard({
    super.key,
    required this.loading,
    required this.recoveryScore,
    required this.trainingLoadScore,
    this.scoreDayLabel,
    this.onTap,
  });

  final bool loading;
  final double? recoveryScore;
  final double? trainingLoadScore;
  final String? scoreDayLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2EC4B6);
    final loadText = trainingLoadScore != null
        ? trainingLoadScore!.round().toString()
        : (loading ? "..." : "--");
    final subtitleParts = <String>[
      if (recoveryScore != null) "Recovery ${recoveryScore!.round()}",
      if (scoreDayLabel != null) scoreDayLabel!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? (loading ? null : "No score data")
        : subtitleParts.join(" | ");

    return StatCard(
      title: "Recovery & load",
      value: "Load $loadText",
      subtitle: subtitle,
      icon: Icons.monitor_heart,
      accentColor: accent,
      onTap: onTap,
    );
  }
}
