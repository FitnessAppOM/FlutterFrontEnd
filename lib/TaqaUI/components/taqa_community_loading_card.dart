import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Shared loading state for Community lists and detail screens.
class TaqaCommunityLoadingCard extends StatelessWidget {
  const TaqaCommunityLoadingCard({
    super.key,
    this.label = 'Loading community...',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: TaqaUiScale.w(28),
            height: TaqaUiScale.h(28),
            child: CircularProgressIndicator(
              strokeWidth: TaqaUiScale.w(2),
              color: TaqaUiColors.charcoal,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(9),
              color: TaqaUiColors.charcoal.withValues(alpha: 0.56),
            ),
          ),
        ],
      ),
    );
  }
}
