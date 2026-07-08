import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// A single filter option in the discover community grid.
///
/// Fixed to the same 109x45 / radius-5 footprint as
/// [TaqaCommunityActionRow]'s buttons, styled with a white fill when
/// unselected and inverted (charcoal fill, white label) when selected.
class TaqaCommunityFilterChip extends StatelessWidget {
  const TaqaCommunityFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiStyles.actionButtonRadius,
        child: Container(
          height: TaqaUiStyles.actionButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? TaqaUiColors.charcoal : TaqaUiColors.white,
            borderRadius: TaqaUiStyles.actionButtonRadius,
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? TaqaUiStyles.communityActionButtonLabel
                : TaqaUiStyles.communityFilterChipLabel,
          ),
        ),
      ),
    );
  }
}

/// Lays out [TaqaCommunityFilterChip]s three to a row, matching the
/// discover page's filter grid.
class TaqaCommunityFilterGrid extends StatelessWidget {
  const TaqaCommunityFilterGrid({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final gap = TaqaUiScale.w(15);
    final runGap = TaqaUiScale.h(15);
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth =
            (constraints.maxWidth - gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: gap,
          runSpacing: runGap,
          children: [
            for (var index = 0; index < labels.length; index++)
              SizedBox(
                width: chipWidth,
                child: TaqaCommunityFilterChip(
                  label: labels[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        );
      },
    );
  }
}
