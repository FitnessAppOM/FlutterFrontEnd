import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/daily_outlook/daily_outlook_service.dart';
import '../styles/taqa_ui_scale.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class DailyOutlookCard extends StatelessWidget {
  const DailyOutlookCard({
    super.key,
    required this.loading,
    required this.generating,
    required this.status,
    required this.onGenerate,
    required this.onOpen,
    required this.title,
    required this.subtitle,
    required this.generateLabel,
    required this.generatedLabel,
    required this.onceDailyLabel,
    required this.viewLabel,
  });

  final bool loading;
  final bool generating;
  final DailyOutlookStatus? status;
  final VoidCallback? onGenerate;
  final VoidCallback? onOpen;
  final String title;
  final String subtitle;
  final String generateLabel;
  final String generatedLabel;
  final String onceDailyLabel;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    final outlook = status?.outlook;
    final generated = status?.generated == true && outlook != null;
    final tagText = generated && outlook.readinessState.trim().isNotEmpty
        ? outlook.readinessState.trim()
        : 'DAILY OUTLOOK';
    final headlineText = generated && outlook.headline.trim().isNotEmpty
        ? outlook.headline.trim()
        : generateLabel;
    final summaryText = generated && outlook.summary.trim().isNotEmpty
        ? outlook.summary.trim()
        : subtitle;
    final busy = loading || generating;
    final actionText = generating
        ? "$generateLabel..."
        : (generated ? viewLabel : generateLabel);
    final onTap = busy ? null : (generated ? onOpen : onGenerate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          TaqaUiStyles.dailyOutlookCardWidth,
        );
        final layoutScale = math.min(
          1.0,
          cardWidth / TaqaUiStyles.dailyOutlookCardWidth,
        );
        final cardHeight = TaqaUiStyles.dailyOutlookCardHeight;
        final leftInset = TaqaUiScale.w(14) * layoutScale;
        final tagTop = TaqaUiScale.h(8) * layoutScale;
        final tagHeight = TaqaUiScale.h(10) * layoutScale;
        final busyIndicatorWidth = busy ? TaqaUiScale.w(24) * layoutScale : 0.0;
        final titleTop = TaqaUiScale.h(48) * layoutScale;
        final titleHeight = TaqaUiScale.h(25) * layoutScale;
        final descriptionTop = TaqaUiScale.h(72) * layoutScale;
        final descriptionWidth =
            TaqaUiStyles.dailyOutlookContentWidth * layoutScale;
        final buttonTop = TaqaUiScale.h(140) * layoutScale;
        final buttonHeight = TaqaUiScale.h(45) * layoutScale;
        final tagWidth = math.max(
          0.0,
          cardWidth - (leftInset * 2) - busyIndicatorWidth,
        );
        final titleWidth = math.max(
          0.0,
          cardWidth - (leftInset * 2),
        );
        final descriptionBottomGap = TaqaUiScale.h(8) * layoutScale;
        final descriptionHeight = math.max(
          0.0,
          buttonTop - descriptionTop - descriptionBottomGap,
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiStyles.dailyOutlookCardRadius,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: leftInset,
                    top: tagTop,
                    width: tagWidth,
                    height: tagHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tagText.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaqaUiStyles.dailyOutlookTag,
                      ),
                    ),
                  ),
                  if (busy)
                    Positioned(
                      right: leftInset,
                      top: TaqaUiScale.h(6) * layoutScale,
                      width: TaqaUiScale.w(16) * layoutScale,
                      height: TaqaUiScale.h(16) * layoutScale,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                  Positioned(
                    left: leftInset,
                    top: titleTop,
                    width: titleWidth,
                    height: titleHeight,
                    child: Text(
                      headlineText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.dailyOutlookTitle,
                    ),
                  ),
                  Positioned(
                    left: leftInset,
                    top: descriptionTop,
                    width: math.min(
                      descriptionWidth,
                      cardWidth - (leftInset * 2),
                    ),
                    height: descriptionHeight,
                    child: Text(
                      summaryText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.dailyOutlookDescription,
                    ),
                  ),
                  Positioned(
                    left: leftInset,
                    top: buttonTop,
                    width: math.min(
                      descriptionWidth,
                      cardWidth - (leftInset * 2),
                    ),
                    height: buttonHeight,
                    child: _DailyOutlookActionButton(
                      label: actionText,
                      onTap: onTap,
                      height: buttonHeight,
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

class _DailyOutlookActionButton extends StatelessWidget {
  const _DailyOutlookActionButton({
    required this.label,
    this.onTap,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height ?? TaqaUiStyles.actionButtonHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: TaqaUiStyles.actionButtonRadius,
          child: Ink(
            decoration: BoxDecoration(
              color: onTap == null
                  ? TaqaUiColors.lime.withValues(alpha: 0.6)
                  : TaqaUiColors.lime,
              borderRadius: TaqaUiStyles.actionButtonRadius,
            ),
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: TaqaUiStyles.dailyOutlookButton,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
