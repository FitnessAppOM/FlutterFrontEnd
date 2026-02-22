import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopRecoveryCard extends StatelessWidget {
  const WhoopRecoveryCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.score,
    this.delta,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final int? score;
  final int? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF4A8BFF);
    final value = linked
        ? (score != null ? "$score%" : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked
        ? (score != null ? "Recovery" : "No data")
        : "Connect Whoop";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Recovery",
          value: value,
          subtitle: subtitle,
          icon: Icons.monitor_heart,
          accentColor: const Color(0xFF4CD964),
          borderColor: whoopBlue,
          borderWidth: 2.5,
          deltaPercent: delta,
          onTap: onTap,
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
}
