import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Plain white card of label/value metric rows — the same row style used
/// inside [TaqaPillarCard]'s expanded detail section, extracted so pages
/// that already show their headline metric elsewhere (e.g. an arc strip)
/// can still list the supporting metrics underneath without the card's
/// tap-to-expand wrapper.
class TaqaMetricDetailList extends StatelessWidget {
  const TaqaMetricDetailList({
    super.key,
    required this.details,
    required this.detailLabels,
  });

  final Map<String, String> details;
  final Map<String, String> detailLabels;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final rows = detailLabels.entries
        .where((entry) => details[entry.key] != null)
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].value,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: colors.textSecondary,
                      fontSize: TaqaUiScale.sp(13),
                    ),
                  ),
                  Text(
                    details[rows[i].key]!,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: colors.textPrimary,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w600,
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
