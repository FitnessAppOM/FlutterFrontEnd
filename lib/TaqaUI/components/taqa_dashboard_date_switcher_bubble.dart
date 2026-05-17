import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

class TaqaDashboardDateSwitcherBubble extends StatelessWidget {
  const TaqaDashboardDateSwitcherBubble({
    super.key,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.onTap,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: TaqaUiColors.graphite.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: TaqaUiColors.charcoal.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: TaqaUiColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: TaqaUiColors.charcoal,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  Text(
                    secondaryLabel,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                      fontSize: 8,
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.graphite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
