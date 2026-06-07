import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import 'taqa_intro_action_button.dart';

class TaqaIntroActionsRow extends StatelessWidget {
  const TaqaIntroActionsRow({
    super.key,
    this.onTrainingTap,
    this.onDietTap,
    this.buttonHeight,
  });

  final VoidCallback? onTrainingTap;
  final VoidCallback? onDietTap;
  final double? buttonHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedButtonHeight = buttonHeight ?? TaqaUiStyles.actionButtonHeight;
    final buttonGap = TaqaUiScale.w(15);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedRowWidth = (TaqaUiStyles.actionButtonWidth * 2) + buttonGap;
        if (constraints.maxWidth >= fixedRowWidth) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TaqaIntroActionButton(
                label: 'GO TO TRAINING',
                onTap: onTrainingTap,
                width: TaqaUiStyles.actionButtonWidth,
                height: resolvedButtonHeight,
              ),
              TaqaIntroActionButton(
                label: 'GO TO DIET',
                onTap: onDietTap,
                width: TaqaUiStyles.actionButtonWidth,
                height: resolvedButtonHeight,
              ),
            ],
          );
        }

        // Keep layout usable on narrow widths while preserving button height.
        final compactButtonWidth = (constraints.maxWidth - buttonGap) / 2;
        return Row(
          children: [
            Expanded(
              child: TaqaIntroActionButton(
                label: 'GO TO TRAINING',
                onTap: onTrainingTap,
                width: compactButtonWidth,
                height: resolvedButtonHeight,
              ),
            ),
            SizedBox(width: buttonGap),
            Expanded(
              child: TaqaIntroActionButton(
                label: 'GO TO DIET',
                onTap: onDietTap,
                width: compactButtonWidth,
                height: resolvedButtonHeight,
              ),
            ),
          ],
        );
      },
    );
  }
}
