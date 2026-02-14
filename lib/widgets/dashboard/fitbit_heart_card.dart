import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitHeartCard extends StatelessWidget {
  final bool loading;
  final int? restingHr;
  final double? hrvRmssd;
  final String? vo2Max;
  final VoidCallback? onTap;

  const FitbitHeartCard({
    super.key,
    required this.loading,
    required this.restingHr,
    required this.hrvRmssd,
    required this.vo2Max,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitDark = Color(0xFF0C6A73);
    final value = restingHr != null ? "${restingHr} bpm" : (loading ? "…" : "—");
    final hrv = hrvRmssd != null ? "HRV ${hrvRmssd!.toStringAsFixed(0)}" : null;
    final vo2 = vo2Max != null && vo2Max!.isNotEmpty ? "VO₂ ${vo2Max!}" : null;
    final subtitle = [hrv, vo2].whereType<String>().join(" • ");

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Heart & cardio",
          value: value,
          subtitle: subtitle.isEmpty ? null : subtitle,
          icon: Icons.favorite,
          accentColor: fitbitDark,
          borderColor: fitbitDark,
          borderWidth: 2.2,
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
}
