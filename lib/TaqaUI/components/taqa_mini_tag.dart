import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// Small rounded pill for a single label — light gray fill, no border.
/// Shared meta-tag look (e.g. attachment/entry type tags on a feed card).
class TaqaMiniTag extends StatelessWidget {
  const TaqaMiniTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: TaqaUiColors.lightGray,
        borderRadius: TaqaUiScale.radius(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TaqaUiStyles.dailyOutlookDescription,
      ),
    );
  }
}
