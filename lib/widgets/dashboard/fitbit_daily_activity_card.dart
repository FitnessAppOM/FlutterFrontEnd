import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitDailyActivityCard extends StatelessWidget {
  final bool loading;
  final int? steps;
  final double? distanceKm;
  final int? calories;
  final int? activeMinutes;
  final VoidCallback? onTap;

  const FitbitDailyActivityCard({
    super.key,
    required this.loading,
    required this.steps,
    required this.distanceKm,
    required this.calories,
    required this.activeMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = activeMinutes != null ? "$activeMinutes min" : (loading ? "…" : "0 min");
    final dist = distanceKm == null ? "—" : "${distanceKm!.toStringAsFixed(1)} km";
    final subtitle = loading ? "" : "$dist";

    const fitbitDark = Color(0xFF0C6A73);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Fitbit activity",
          value: value,
          subtitle: subtitle,
          icon: Icons.directions_walk,
          accentColor: fitbitDark,
          borderColor: fitbitDark,
          borderWidth: 2.2,
          footerRight: null,
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
