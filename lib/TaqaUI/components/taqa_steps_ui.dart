import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_value_dialog.dart' as taqa_value_dialog;

class TaqaRangeTab extends StatelessWidget {
  const TaqaRangeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: TaqaUiScale.radius(5),
      child: Container(
        height: TaqaUiScale.h(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TaqaUiColors.unnamedColorE4e93b
              : TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(5),
          border: selected
              ? null
              : Border.all(
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(
                    alpha: 0.12,
                  ),
                ),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
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
    );
  }
}

class TaqaTagButton extends StatelessWidget {
  const TaqaTagButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: TaqaUiScale.radius(5),
      child: Container(
        padding: TaqaUiScale.insetsLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: TaqaUiScale.radius(5),
          border: Border.all(
            color: TaqaUiColors.unnamedColor1c1d17,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: TaqaUiScale.w(10),
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
            SizedBox(width: TaqaUiScale.w(4)),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: TaqaUiScale.sp(8),
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 10 / 8,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showTaqaValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
}) async {
  return taqa_value_dialog.showTaqaValueDialog(
    context: context,
    title: title,
    initialValue: initialValue,
  );
}

Future<String?> showTaqaTextValueDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  TextInputType keyboardType = TextInputType.number,
}) async {
  return taqa_value_dialog.showTaqaTextValueDialog(
    context: context,
    title: title,
    initialValue: initialValue,
    keyboardType: keyboardType,
  );
}
