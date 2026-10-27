import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaFilledButton extends StatelessWidget {
  const TaqaFilledButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.height = 48,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w700,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final disabled = onTap == null || loading;
    return Material(
      color: disabled ? colors.accent.withValues(alpha: 0.4) : colors.accent,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: disabled ? null : onTap,
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(height),
          child: Center(
            child: loading
                ? SizedBox(
                    width: TaqaUiScale.w(18),
                    height: TaqaUiScale.h(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onAccent,
                    ),
                  )
                : Text(
                    taqaUppercase(label),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(fontSize),
                      fontWeight: fontWeight,
                      height: 12 / fontSize,
                      letterSpacing: 0,
                      color: colors.onAccent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Borderless secondary action used for Cancel-style controls in Taqa forms.
class TaqaTextActionButton extends StatelessWidget {
  const TaqaTextActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(5),
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: TaqaUiScale.w(17),
                  color: foregroundColor ?? colors.textPrimary,
                ),
                SizedBox(width: TaqaUiScale.w(7)),
              ],
              Text(
                taqaUppercase(label),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(10),
                  fontWeight: FontWeight.w600,
                  height: 12 / 10,
                  letterSpacing: 0,
                  color: foregroundColor ?? colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
