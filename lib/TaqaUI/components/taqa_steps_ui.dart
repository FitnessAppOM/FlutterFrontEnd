import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
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
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TaqaUiColors.unnamedColorE4e93b
              : TaqaUiColors.white,
          borderRadius: BorderRadius.circular(5),
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
          style: const TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.2,
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
    final border = TaqaUiColors.graphite.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: TaqaUiColors.unnamedColor1c1d17),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: 8,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
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
