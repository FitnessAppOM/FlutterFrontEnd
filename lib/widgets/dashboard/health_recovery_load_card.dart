import 'package:flutter/material.dart';

import '../../TaqaUI/components/taqa_progress_widget_card.dart';
import '../../services/health/health_recovery_load_service.dart';

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
    final value = activeMinutes != null
        ? "${activeMinutes}m"
        : (loading
              ? "…"
              : (restingHr != null ? "$restingHr bpm" : "—"));
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
        ? (loading ? "Loading" : "No health data")
        : subtitleParts.join(" | ");

    return TaqaProgressWidgetCard(
      title: "Recovery & load",
      valueText: value,
      goalText: subtitle,
      progress: 0.0,
      showArc: false,
      loading: loading &&
          activeMinutes == null &&
          restingHr == null &&
          hrvMs == null &&
          zones == null,
      onTap: onTap,
    );
  }
}
