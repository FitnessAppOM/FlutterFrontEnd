import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// A single filter option in the discover community grid.
///
/// Fixed to the same 109x45 / radius-5 footprint as
/// [TaqaCommunityActionRow]'s buttons: white with no border when
/// unselected, lime fill with a hairline charcoal border and a small
/// close mark when selected.
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
          decoration: BoxDecoration(
            color: selected ? TaqaUiColors.accent : TaqaUiColors.white,
            borderRadius: TaqaUiStyles.actionButtonRadius,
            border: selected
                ? Border.all(color: TaqaUiColors.charcoal, width: 0.5)
                : null,
          ),
          child: Stack(
            // Fill the whole 109x45 chip so the Positioned close mark below
            // is measured from the chip's actual corner, not from a Stack
            // that's shrunk to fit just the label text.
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaqaUiStyles.communityFilterChipLabel,
                ),
              ),
              if (selected)
                Positioned(
                  // Spec's close mark is centered at (118.5, 155.5) on a
                  // chip anchored at (16, 148) — i.e. (102.5, 7.5) local.
                  top: TaqaUiScale.h(3.5),
                  right: TaqaUiScale.w(2.5),
                  child: Icon(
                    Icons.close,
                    size: TaqaUiScale.sp(8),
                    color: TaqaUiColors.charcoal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out [TaqaCommunityFilterChip]s three to a row, matching the
/// discover page's filter grid. Each chip toggles independently so the
/// user can mix multiple filters at once instead of picking a single one.
class TaqaCommunityFilterGrid extends StatelessWidget {
  const TaqaCommunityFilterGrid({
    super.key,
    required this.labels,
    required this.selectedIndexes,
    required this.onToggle,
  });

  final List<String> labels;
  final Set<int> selectedIndexes;
  final ValueChanged<int> onToggle;

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
                  selected: selectedIndexes.contains(index),
                  onTap: () => onToggle(index),
                ),
              ),
          ],
        );
      },
    );
  }
}
