import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaLinearMetricCard extends StatelessWidget {
  const TaqaLinearMetricCard({
    super.key,
    required this.title,
    required this.valueText,
    required this.subtitle,
    required this.progress,
    this.loading = false,
    this.lightSurface = true,
    this.showBar = true,
    this.keepBarSpaceWhenHidden = true,
  });

  final String title;
  final String valueText;
  final String subtitle;
  final double progress;
  final bool loading;
  final bool lightSurface;
  final bool showBar;
  final bool keepBarSpaceWhenHidden;

  @override
  Widget build(BuildContext context) {
    final clamped = loading ? 0.0 : progress.clamp(0.0, 1.0).toDouble();
    final surfaceColor = lightSurface
        ? TaqaUiColors.white
        : TaqaUiColors.charcoal;
    final textColor = lightSurface
        ? TaqaUiColors.unnamedColor1c1d17
        : TaqaUiColors.white;
    final valueBarColor = lightSurface
        ? TaqaUiColors.charcoal
        : TaqaUiColors.lightGray;

    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: textColor,
              letterSpacing: 0,
              height: 10 / 8,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(20)),
          if (loading)
            SizedBox(
              width: TaqaUiScale.w(16),
              height: TaqaUiScale.h(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          else
            Text(
              valueText,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(25),
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1,
              ),
            ),
          SizedBox(height: TaqaUiScale.h(5)),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              color: textColor,
              letterSpacing: 0,
              height: 13 / 8,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          if (showBar)
            Container(
              height: TaqaUiScale.h(17),
              width: double.infinity,
              decoration: BoxDecoration(
                color: TaqaUiColors.unnamedColorE3e3e3,
                borderRadius: TaqaUiScale.radius(9),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      color: valueBarColor,
                      borderRadius: TaqaUiScale.radius(9),
                    ),
                  ),
                ),
              ),
            )
          else if (keepBarSpaceWhenHidden)
            SizedBox(height: TaqaUiScale.h(17), width: double.infinity),
        ],
      ),
    );
  }
}
