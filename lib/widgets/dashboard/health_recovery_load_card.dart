import 'package:flutter/material.dart';

import '../../services/health/health_recovery_load_service.dart';
import 'stat_card.dart';

class HealthRecoveryLoadCard extends StatelessWidget {
  const HealthRecoveryLoadCard({
    super.key,
    required this.loading,
    required this.restingHr,
    required this.hrvMs,
    required this.activeMinutes,
    required this.zones,
    this.onTap,
  });

  final bool loading;
  final int? restingHr;
  final double? hrvMs;
  final int? activeMinutes;
  final HealthHeartZones? zones;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2EC4B6);
    final value = activeMinutes != null
        ? "$activeMinutes min"
        : (loading ? "…" : "—");
    final rhrText = restingHr != null ? "RHR $restingHr bpm" : null;
    final hrvText = hrvMs != null
        ? "HRV ${hrvMs!.toStringAsFixed(0)} ms"
        : null;
    final zonesText = zones != null
        ? "Zones ${zones!.outOfRangeMinutes}/${zones!.fatBurnMinutes}/${zones!.cardioMinutes}/${zones!.peakMinutes}"
        : null;
    final subtitleParts = [
      rhrText,
      hrvText,
      zonesText,
    ].whereType<String>().toList();
    final subtitle = subtitleParts.isEmpty
        ? (loading ? null : "No health data")
        : subtitleParts.join(" • ");

    return StatCard(
      title: "Recovery & load",
      value: value,
      subtitle: subtitle,
      icon: Icons.monitor_heart,
      accentColor: accent,
      onTap: onTap,
    );
  }
}
