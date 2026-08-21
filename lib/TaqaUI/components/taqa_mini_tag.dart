import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

const Set<String> _taqaTagAcronyms = {
  'ai',
  'amrap',
  'bmi',
  'bmr',
  'emom',
  'gps',
  'hiit',
  'hr',
  'hrv',
  'pb',
  'pr',
  'rir',
  'rpe',
  'rpm',
  'vo2',
};

/// Converts backend tag keys into readable labels while preserving common
/// fitness abbreviations: `score_improvements` becomes `Score improvements`
/// and `pr` becomes `PR`.
String taqaFormatTagLabel(String rawLabel) {
  final words = rawLabel
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        final lower = word.toLowerCase();
        return _taqaTagAcronyms.contains(lower) ? lower.toUpperCase() : lower;
      })
      .toList(growable: false);
  if (words.isEmpty) return '';

  final first = words.first;
  if (!_taqaTagAcronyms.contains(first.toLowerCase())) {
    words[0] = '${first[0].toUpperCase()}${first.substring(1)}';
  }
  return words.join(' ');
}

/// Small rounded pill for a single label — light gray fill, no border.
/// Shared meta-tag look (e.g. attachment/entry type tags on a feed card).
class TaqaMiniTag extends StatelessWidget {
  const TaqaMiniTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
        style: TaqaUiStyles.dailyOutlookDescription.copyWith(
          height: isArabic ? 1.45 : null,
        ),
      ),
    );
  }
}
