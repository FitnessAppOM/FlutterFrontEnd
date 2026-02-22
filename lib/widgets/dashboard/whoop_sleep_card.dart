import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopSleepCard extends StatelessWidget {
  const WhoopSleepCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.linkedKnown,
    required this.hours,
    required this.score,
    required this.goal,
    this.delta,
    this.onTap,
    this.showEfficiency = true,
  });

  final bool loading;
  final bool linked;
  final bool linkedKnown;
  final double? hours;
  final int? score;
  final double? goal;
  final int? delta;
  final VoidCallback? onTap;
  final bool showEfficiency;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF4A8BFF);
    final value = !linkedKnown
        ? "…"
        : linked
            ? (hours != null ? _formatHours(hours!) : (loading ? "…" : "—"))
            : "Not connected";
    final subtitle = (goal != null ? "Goal: ${_formatHours(goal!)}" : null);
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
          deltaPercent: deltaValue,
          footerLeft: showEfficiency && efficiency != null
              ? Text(
                  "Efficiency: ${efficiency.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
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
            child: Image.asset(
              'assets/images/whoop.png',
              height: 14,
              fit: BoxFit.contain,
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
