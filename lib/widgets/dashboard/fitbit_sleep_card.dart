import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitSleepCard extends StatelessWidget {
  final bool loading;
  final int? minutesAsleep;
  final int? minutesInBed;
  final int? goalMinutes;
  final VoidCallback? onTap;

  const FitbitSleepCard({
    super.key,
    required this.loading,
    required this.minutesAsleep,
    required this.minutesInBed,
    required this.goalMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitDark = Color(0xFF0C6A73);
    final value = minutesAsleep != null
        ? _fmtMinutes(minutesAsleep!)
        : (loading ? "…" : "—");
    final subtitle = goalMinutes != null ? "Goal: ${_fmtMinutes(goalMinutes!)}" : null;

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
}
