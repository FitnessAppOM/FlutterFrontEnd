import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaEmptyCard extends StatelessWidget {
  const TaqaEmptyCard({
    super.key,
    required this.title,
    this.subtitle,
    this.loading = false,
    this.icon = Icons.nightlight_round,
    this.minHeight,
  });

  final String title;
  final String? subtitle;
  final bool loading;
  final IconData icon;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? TaqaUiScale.h(160)),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: TaqaUiScale.h(28)),
          Container(
            width: TaqaUiScale.w(36),
            height: TaqaUiScale.h(36),
            decoration: const BoxDecoration(
              color: TaqaUiColors.unnamedColor1c1d17,
              shape: BoxShape.circle,
            ),
            child: loading
                ? Padding(
                    padding: EdgeInsets.all(TaqaUiScale.w(10)),
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: TaqaUiColors.unnamedColorE4e93b,
                    ),
                  )
                : Icon(
                    icon,
                    color: TaqaUiColors.unnamedColorE4e93b,
                    size: TaqaUiScale.w(18),
                  ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          Padding(
            padding: TaqaUiScale.symmetric(horizontal: 20),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.unnamedColor1c1d17,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: TaqaUiScale.h(6)),
            Padding(
              padding: TaqaUiScale.symmetric(horizontal: 20),
              child: Text(
                subtitle!.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(8),
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.4),
                  letterSpacing: 0,
                  height: 10 / 8,
                ),
              ),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(28)),
        ],
      ),
    );
  }
}
