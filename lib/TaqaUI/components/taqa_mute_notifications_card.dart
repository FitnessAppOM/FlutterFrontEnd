import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// A group page row for toggling notification mutes: title, description,
/// and an on/off pill switch on the right. Tapping anywhere on the card
/// toggles [value].
class TaqaMuteNotificationsCard extends StatelessWidget {
  const TaqaMuteNotificationsCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Mute Notifications',
    this.description = 'Stay in the group without community alerts.',
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.communityMuteCardWidth,
        );
        final cardHeight = TaqaUiStyles.communityMuteCardHeight;
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.communityMuteCardWidth,
        );

        final contentLeft = TaqaUiScale.w(14) * layoutScale;
        final contentWidth = cardWidth - (contentLeft * 2);
        final titleTop = TaqaUiScale.h(17) * layoutScale;
        final descriptionTop = TaqaUiScale.h(38) * layoutScale;
        final trackWidth = TaqaUiScale.w(38) * layoutScale;
        final trackHeight = TaqaUiScale.h(20) * layoutScale;
        final thumbInset = TaqaUiScale.w(2) * layoutScale;
        final switchTop = TaqaUiScale.h(23) * layoutScale;

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Material(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiStyles.communityGroupCardRadius,
            child: InkWell(
              onTap: onChanged == null ? null : () => onChanged!(!value),
              borderRadius: TaqaUiStyles.communityGroupCardRadius,
              child: Stack(
                children: [
                  Positioned(
                    left: contentLeft,
                    top: titleTop,
                    width: contentWidth,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardName,
                    ),
                  ),
                  Positioned(
                    left: contentLeft,
                    top: descriptionTop,
                    width: contentWidth,
                    child: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardDescription,
                    ),
                  ),
                  Positioned(
                    right: contentLeft,
                    top: switchTop,
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: trackWidth,
                        height: trackHeight,
                        padding: EdgeInsets.all(thumbInset),
                        decoration: BoxDecoration(
                          color: value
                              ? TaqaUiColors.lime
                              : TaqaUiColors.charcoal.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(trackHeight),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: TaqaUiColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
