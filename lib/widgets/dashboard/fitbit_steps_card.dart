import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitStepsCard extends StatelessWidget {
  final bool loading;
  final int? steps;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FitbitStepsCard({
    super.key,
    required this.loading,
    required this.steps,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitTeal = Color(0xFF00B0B9);
    final value = loading ? "…" : "${steps ?? 0}";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Steps",
          value: value,
          subtitle: subtitle,
          icon: Icons.directions_walk,
          accentColor: const Color(0xFF35B6FF),
          borderColor: fitbitTeal,
          borderWidth: 2.5,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
        Positioned(
          top: -10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fitbitTeal,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              "fitbit",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
