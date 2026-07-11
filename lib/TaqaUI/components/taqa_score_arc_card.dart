import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_score_widget.dart' show TaqaOpenArcPainter;

/// The small lime open-arc "value" tile used inside the Taqa Score detail
/// page's day carousel (`_ScorePreviewCard`), generalized with a [size] so it
/// can be reused at any scale (e.g. a row of 3 in [TaqaScoreDayStrip]).
class TaqaScoreArcCard extends StatelessWidget {
  const TaqaScoreArcCard({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.valueDisplay,
    this.caption,
    this.size = 171,
  });

  final double? score;
  final double maxScore;
  final String? valueDisplay;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeMaxScore = maxScore <= 0 ? 100 : maxScore;
    final progress = score == null
        ? 0.0
        : (score! / safeMaxScore).clamp(0.0, 1.0);
    final valueText = score == null
        ? '--'
        : valueDisplay ?? score!.round().toString();

    final scale = size / 171;
    final arcSize = TaqaUiScale.w(141) * scale;
    final visibleHeight = TaqaUiScale.h(124) * scale;
    final arcLeft = TaqaUiScale.w(15) * scale;
    final arcTop = TaqaUiScale.h(27) * scale;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TaqaUiColors.unnamedColorE4e93b,
        borderRadius: TaqaUiScale.radius(15 * scale),
      ),
      child: Stack(
        children: [
          Positioned(
            left: arcLeft,
            top: arcTop,
            width: arcSize,
            height: visibleHeight,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: arcSize,
                maxHeight: arcSize,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: arcSize,
                  height: arcSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(arcSize),
                        painter: TaqaOpenArcPainter(progress: progress),
                      ),
                      Transform.translate(
                        offset: Offset(0, -((arcSize - visibleHeight) / 2)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valueText,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(35) * scale,
                              fontWeight: FontWeight.w800,
                              color: TaqaUiColors.charcoal,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Positioned(
              left: TaqaUiScale.w(15) * scale,
              top: TaqaUiScale.h(132) * scale,
              width: TaqaUiScale.w(141) * scale,
              height: TaqaUiScale.h(10) * scale,
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(8) * scale,
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.charcoal,
                  height: 13 / 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
