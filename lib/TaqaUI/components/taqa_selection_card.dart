import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// White card row used for a labeled value plus a "Set" action button.
///
/// Shared by any screen that lets the user pick a single value from another
/// page (e.g. affiliation, certification) so these selectors look identical
/// wherever they appear.
class TaqaSelectionCard extends StatelessWidget {
  const TaqaSelectionCard({
    super.key,
    required this.label,
    required this.value,
    required this.buttonLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final String buttonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: TaqaUiColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: TaqaUiScale.radius(15),
        // Keeps the card visible even on screens whose background is also
        // white (e.g. the expert questionnaire), matching the grey-page look.
        side: BorderSide(color: TaqaUiColors.border),
      ),
      child: Padding(
        padding: TaqaUiScale.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(4)),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: TaqaUiColors.charcoal,
                // Without this, a disabled onTap (e.g. "Set" while nothing
                // is selectable yet) falls back to Material's default grey
                // instead of staying on-brand.
                disabledForegroundColor: TaqaUiColors.charcoal,
                side: const BorderSide(color: TaqaUiColors.charcoal),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
