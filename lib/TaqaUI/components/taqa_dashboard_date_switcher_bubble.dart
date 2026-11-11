import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Compact calendar entry used by dashboard surfaces.
///
/// Labels are supplied by the feature so this component stays reusable and
/// localization-agnostic.
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
    final colors = context.taqaColors;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colors.textPrimary,
        disabledForegroundColor: colors.textSecondary,
        backgroundColor: colors.surfaceElevated,
        disabledBackgroundColor: colors.surfaceElevated.withValues(alpha: .55),
        minimumSize: Size(0, TaqaUiScale.h(44)),
        padding: TaqaUiScale.insetsLTRB(8, 6, 0, 6),
        shape: RoundedRectangleBorder(
          borderRadius: TaqaUiScale.radius(12),
          side: BorderSide(color: colors.border),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        children: [
          Container(
            width: TaqaUiScale.w(24),
            height: TaqaUiScale.w(24),
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              size: TaqaUiScale.w(13),
              color: colors.onAccent,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(7)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(10),
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(2)),
                Text(
                  secondaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                    fontSize: TaqaUiScale.sp(7),
                    fontWeight: FontWeight.w400,
                    color: colors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
