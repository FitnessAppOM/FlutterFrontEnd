import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

/// A [TaqaMuteNotificationsCard]-styled row for navigating to a settings
/// sub-page: title, description, and a chevron on the right. Tapping
/// anywhere on the card triggers [onTap].
class TaqaSettingsRowCard extends StatelessWidget {
  const TaqaSettingsRowCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
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
        final titleTop = TaqaUiScale.h(17) * layoutScale;
        final descriptionTop = TaqaUiScale.h(38) * layoutScale;
        final chevronSize = TaqaUiScale.w(20) * layoutScale;
        final chevronTop = TaqaUiScale.h(22) * layoutScale;
        final textEnd = contentLeft + chevronSize + TaqaUiScale.w(8);

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Material(
            color: colors.surface,
            borderRadius: TaqaUiStyles.communityGroupCardRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: TaqaUiStyles.communityGroupCardRadius,
              child: Stack(
                children: [
                  PositionedDirectional(
                    start: contentLeft,
                    end: textEnd,
                    top: titleTop,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardName.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: contentLeft,
                    end: textEnd,
                    top: descriptionTop,
                    child: Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.communityGroupCardDescription
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                  PositionedDirectional(
                    end: contentLeft,
                    top: chevronTop,
                    child: IgnorePointer(
                      child: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        size: chevronSize,
                        color: colors.textSecondary,
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
