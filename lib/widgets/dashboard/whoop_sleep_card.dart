import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopSleepCard extends StatelessWidget {
  const WhoopSleepCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.hours,
    required this.score,
    required this.goal,
    this.delta,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final double? hours;
  final int? score;
  final double? goal;
  final int? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF2D7CFF);
    final value = loading
        ? "…"
        : linked
            ? (hours != null ? _formatHours(hours!) : "—")
            : "Not connected";
    final subtitle = goal != null ? "Goal: ${_formatHours(goal!)}" : null;
    final efficiency = score;
    final deltaValue = delta;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Sleep",
          value: value,
          subtitle: subtitle,
          icon: Icons.nights_stay,
          accentColor: AppColors.accent,
          borderColor: whoopBlue,
          borderWidth: 2.5,
          onTap: onTap,
        ),
        if (efficiency != null)
          Positioned(
            bottom: 10,
            left: 14,
            child: Text(
              "Efficiency: ${efficiency.toStringAsFixed(0)}%",
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (deltaValue != null)
          Positioned(
            bottom: 10,
            right: 14,
            child: Row(
              children: [
                Icon(
                  deltaValue >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: deltaValue >= 0 ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
                ),
                const SizedBox(width: 4),
                Text(
                  "${deltaValue.abs()}%",
                  style: TextStyle(
                    color: deltaValue >= 0 ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: -10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: whoopBlue,
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
              "whoop",
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

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}h ${m}m";
  }
}
