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
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? TaqaUiScale.h(160)),
      decoration: BoxDecoration(
        color: colors.surface,
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
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
            child: loading
                ? Padding(
                    padding: EdgeInsets.all(TaqaUiScale.w(10)),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.onAccent,
                    ),
                  )
                : Icon(icon, color: colors.onAccent, size: TaqaUiScale.w(18)),
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
                color: colors.textPrimary,
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
                taqaUppercase(subtitle!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(8),
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
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
