import 'package:flutter/material.dart';

import '../../TaqaUI/components/taqa_progress_widget_card.dart';
import '../../services/health/health_recovery_load_service.dart';
import '../../localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context).translate;
    final value = activeMinutes != null
        ? "${activeMinutes}m"
        : (loading
              ? "…"
              : (restingHr != null ? "$restingHr bpm" : "—"));
    final rhrText = restingHr != null ? "${t("health_rhr_label")} $restingHr bpm" : null;
    final hrvText = hrvMs != null
        ? "${t("health_hrv_label")} ${hrvMs!.toStringAsFixed(0)} ms"
        : null;
    final zonesText = zones != null
        ? "${t("common_zones_short")} ${zones!.outOfRangeMinutes}/${zones!.fatBurnMinutes}/${zones!.cardioMinutes}/${zones!.peakMinutes}"
        : null;
    final subtitleParts = [
      rhrText,
      hrvText,
      zonesText,
    ].whereType<String>().toList();
    final subtitle = subtitleParts.isEmpty
        ? (loading ? t("dash_loading") : t("health_recovery_no_data"))
        : subtitleParts.join(" | ");

    return TaqaProgressWidgetCard(
      title: t("health_recovery_title"),
      valueText: value,
      goalText: subtitle,
      goalScrollable: subtitleParts.isNotEmpty,
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
