import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopRecoveryCard extends StatelessWidget {
  const WhoopRecoveryCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.score,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final int? score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF2D7CFF);
    final value = loading
        ? "…"
        : linked
            ? (score != null ? "$score%" : "—")
            : "Not connected";
    final subtitle = linked
        ? (score != null ? "Last recovery score" : "No data yet for today")
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
}
