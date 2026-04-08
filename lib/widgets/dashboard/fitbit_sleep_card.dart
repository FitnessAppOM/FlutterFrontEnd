import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitSleepCard extends StatelessWidget {
  final bool loading;
  final int? minutesAsleep;
  final int? minutesInBed;
  final int? goalMinutes;
  final int? sleepScore;
  final Map<String, int> stageMinutes;
  final VoidCallback? onTap;

  const FitbitSleepCard({
    super.key,
    required this.loading,
    required this.minutesAsleep,
    required this.minutesInBed,
    required this.goalMinutes,
    this.sleepScore,
    this.stageMinutes = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitDark = Color(0xFF0C6A73);
    final value = minutesAsleep != null
        ? _fmtMinutes(minutesAsleep!)
        : (loading ? "…" : "—");
    final subtitle = _buildSubtitle(_buildStageSummary());

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Fitbit sleep",
          value: value,
          subtitle: subtitle,
          icon: Icons.nights_stay,
          accentColor: fitbitDark,
          borderColor: fitbitDark,
          borderWidth: 2.2,
          footerLeft: sleepScore != null
              ? Text(
                  "Score: ${sleepScore!.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          onTap: onTap,
        ),
        Positioned(
          top: -10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fitbitDark,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/fitbit.png',
              height: 14,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "${h}h ${m}m";
  }

  String? _buildSubtitle(String? stageSummary) {
    final goalLabel = goalMinutes != null
        ? "Goal: ${_fmtMinutes(goalMinutes!)}"
        : null;
    if (goalLabel != null && stageSummary != null) {
      return "$goalLabel • $stageSummary";
    }
    return goalLabel ?? stageSummary;
  }

  String? _buildStageSummary() {
    if (loading || stageMinutes.isEmpty) return null;
    final deep = _stageValue("deep");
    final light = _stageValue("light");
    final rem = _stageValue("rem");
    final parts = <String>[];
    if (deep != null && deep > 0) parts.add("D ${_fmtMinutes(deep)}");
    if (light != null && light > 0) parts.add("L ${_fmtMinutes(light)}");
    if (rem != null && rem > 0) parts.add("R ${_fmtMinutes(rem)}");
    return parts.isEmpty ? null : parts.join(" • ");
  }

  int? _stageValue(String key) {
    if (stageMinutes.isEmpty) return null;
    if (stageMinutes.containsKey(key)) return stageMinutes[key];
    final lower = key.toLowerCase();
    for (final entry in stageMinutes.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}
