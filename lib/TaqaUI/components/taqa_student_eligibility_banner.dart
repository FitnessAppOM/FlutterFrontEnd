import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Confirms that the signed-in account can access verified student pricing.
class TaqaStudentEligibilityBanner extends StatelessWidget {
  const TaqaStudentEligibilityBanner({
    super.key,
    required this.title,
    required this.details,
  });

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $details',
      child: Container(
        width: double.infinity,
        padding: TaqaUiScale.insetsLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: TaqaUiColors.accent,
          borderRadius: TaqaUiScale.radius(10),
        ),
        child: Row(
          children: [
            Container(
              width: TaqaUiScale.w(34),
              height: TaqaUiScale.h(34),
              decoration: BoxDecoration(
                color: TaqaUiColors.charcoal,
                borderRadius: TaqaUiScale.radius(8),
              ),
              child: Icon(
                Icons.school_rounded,
                size: TaqaUiScale.w(19),
                color: TaqaUiColors.accent,
              ),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w800,
                      height: 16 / 13,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(2)),
                  Text(
                    details,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(11),
                      fontWeight: FontWeight.w500,
                      height: 15 / 11,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: TaqaUiScale.w(8)),
            Icon(
              Icons.verified_rounded,
              size: TaqaUiScale.w(20),
              color: TaqaUiColors.charcoal,
            ),
          ],
        ),
      ),
    );
  }
}
