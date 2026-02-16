import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitBodyCard extends StatelessWidget {
  final bool loading;
  final double? weightKg;
  final VoidCallback? onTap;

  const FitbitBodyCard({
    super.key,
    required this.loading,
    required this.weightKg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitDark = Color(0xFF0C6A73);
    final value = loading
        ? "…"
        : weightKg != null
            ? "${weightKg!.toStringAsFixed(1)} kg"
            : "—";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Fitbit body",
          value: value,
          icon: Icons.monitor_weight,
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
