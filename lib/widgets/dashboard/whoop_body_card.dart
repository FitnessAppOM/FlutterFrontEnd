import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stat_card.dart';

class WhoopBodyCard extends StatelessWidget {
  const WhoopBodyCard({
    super.key,
    required this.loading,
    required this.linked,
    required this.onTap,
  });

  final bool loading;
  final bool linked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const whoopBlue = Color(0xFF2D7CFF);
    final value = loading
        ? "…"
        : linked
            ? "Measurements"
            : "Not connected";
    final subtitle = linked ? "Height · Weight · Max HR" : "Connect Whoop";

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
