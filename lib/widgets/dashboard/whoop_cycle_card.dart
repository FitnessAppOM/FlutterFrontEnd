import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopCycleCard extends StatelessWidget {
  const WhoopCycleCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.strain,
    this.onTap,
  });

  final bool loading;
  final bool linked;
  final double? strain;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF4A8BFF);
    final value = linked
        ? (strain != null ? _fmt(strain) : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked
        ? (strain != null ? "Last strain score" : "No cycle data yet")
        : "Connect Whoop";
    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Daily Cycle",
          value: value,
          subtitle: subtitle,
          icon: Icons.loop,
          accentColor: const Color(0xFF2D7CFF),
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

  String _fmt(double? v) {
    if (v == null) return "—";
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
