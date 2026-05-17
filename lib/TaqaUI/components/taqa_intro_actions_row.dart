import 'package:flutter/material.dart';

import '../styles/taqa_ui_styles.dart';
import 'taqa_intro_action_button.dart';

class TaqaIntroActionsRow extends StatelessWidget {
  const TaqaIntroActionsRow({
    super.key,
    this.onTrainingTap,
    this.onDietTap,
    this.buttonHeight = TaqaUiStyles.actionButtonHeight,
  });

  final VoidCallback? onTrainingTap;
  final VoidCallback? onDietTap;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedRowWidth = (TaqaUiStyles.actionButtonWidth * 2) + 12;
        if (constraints.maxWidth >= fixedRowWidth) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TaqaIntroActionButton(
                label: 'GO TO TRAINING',
                onTap: onTrainingTap,
                width: TaqaUiStyles.actionButtonWidth,
                height: buttonHeight,
              ),
              TaqaIntroActionButton(
                label: 'GO TO DIET',
                onTap: onDietTap,
                width: TaqaUiStyles.actionButtonWidth,
                height: buttonHeight,
              ),
            ],
          );
        }

        // Keep layout usable on narrow widths while preserving button height.
        final compactButtonWidth = (constraints.maxWidth - 12) / 2;
        return Row(
          children: [
            Expanded(
              child: TaqaIntroActionButton(
                label: 'GO TO TRAINING',
                onTap: onTrainingTap,
                width: compactButtonWidth,
                height: buttonHeight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TaqaIntroActionButton(
                label: 'GO TO DIET',
                onTap: onDietTap,
                width: compactButtonWidth,
                height: buttonHeight,
              ),
            ),
          ],
        );
      },
    );
  }
}
