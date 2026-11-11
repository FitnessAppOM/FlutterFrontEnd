import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';
import 'taqa_outline_tag_button.dart';

/// Compact dashboard calendar action matching the dashboard streak tag.
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
    return TaqaOutlineTagButton(
      label: label,
      width: width,
      height: TaqaUiStyles.streakTagHeight,
      onTap: onTap,
      icon: Icon(
        Icons.calendar_month_outlined,
        size: TaqaUiScale.w(10),
        color: colors.textPrimary,
      ),
    );
  }
}
