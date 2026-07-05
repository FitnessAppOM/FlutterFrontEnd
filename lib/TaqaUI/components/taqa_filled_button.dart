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
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

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
          height: TaqaUiScale.h(48),
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
                      fontSize: TaqaUiScale.sp(11),
                      fontWeight: FontWeight.w700,
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
