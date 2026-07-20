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
    final disabled = onTap == null || loading;
    return Material(
      color: disabled
          ? TaqaUiColors.unnamedColorE4e93b.withValues(alpha: 0.4)
          : TaqaUiColors.unnamedColorE4e93b,
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
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  )
                : Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(fontSize),
                      fontWeight: fontWeight,
                      height: 12 / fontSize,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
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
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(5),
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w600,
                height: 12 / 10,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
