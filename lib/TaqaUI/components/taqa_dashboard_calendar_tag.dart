import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';
import 'taqa_outline_tag_button.dart';

/// Compact dashboard calendar action matching the dashboard streak tag.
///
/// Hugs its icon + label like the streak tag; [width] is only an upper bound
/// so long translations ellipsize instead of growing the card.
class TaqaDashboardCalendarTag extends StatelessWidget {
  const TaqaDashboardCalendarTag({
    super.key,
    required this.label,
    required this.width,
    this.onTap,
  });

  final String label;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: TaqaOutlineTagButton(
        label: label,
        height: TaqaUiStyles.streakTagHeight,
        padding: TaqaUiScale.w(6),
        onTap: onTap,
        icon: Icon(
          Icons.calendar_month_outlined,
          size: TaqaUiScale.w(9),
          color: colors.textPrimary,
        ),
      ),
    );
  }
}
