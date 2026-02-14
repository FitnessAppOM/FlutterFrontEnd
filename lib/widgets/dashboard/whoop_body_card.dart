import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopBodyCard extends StatelessWidget {
  const WhoopBodyCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.weightKg,
    required this.onTap,
  });

  final bool loading;
  final bool linked;
  final double? weightKg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF4A8BFF);
    final value = linked
        ? (weightKg != null
            ? "${weightKg!.toStringAsFixed(1)} kg"
            : (loading ? "…" : "—"))
        : "Not connected";
    final subtitle = linked ? "Current weight" : "Connect Whoop";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Body",
          value: value,
          subtitle: subtitle,
          icon: Icons.person,
          accentColor: AppColors.accent,
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
}
