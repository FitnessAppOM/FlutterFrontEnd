import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
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
    final baseBarColor = lightSurface
        ? TaqaUiColors.lightGray
        : TaqaUiColors.graphite;
    final valueBarColor = lightSurface
        ? TaqaUiColors.charcoal
        : TaqaUiColors.lightGray;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
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
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.0,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: textColor,
              letterSpacing: 0,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (showBar)
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseBarColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      color: valueBarColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            )
          else if (keepBarSpaceWhenHidden)
            const SizedBox(height: 20, width: double.infinity),
        ],
      ),
    );
  }
}
