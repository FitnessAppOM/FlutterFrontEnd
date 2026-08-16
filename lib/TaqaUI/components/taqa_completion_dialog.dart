import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_filled_button.dart';
import 'taqa_popup_guard.dart';
import 'taqa_value_dialog.dart';

/// Displays a celebratory TaqaUI dialog and prevents duplicate popup routes.
Future<bool> showTaqaCompletionDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String buttonLabel,
  String? eyebrow,
}) async {
  final acknowledged = await TaqaPopupGuard.open<bool>(
    context: context,
    show: () => showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) => TaqaPopupDialog(
        padding: TaqaUiScale.insetsLTRB(20, 20, 20, 20),
        child: _TaqaCompletionDialogContent(
          title: title,
          message: message,
          buttonLabel: buttonLabel,
          eyebrow: eyebrow,
          onDone: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    ),
  );
  return acknowledged == true;
}

class _TaqaCompletionDialogContent extends StatelessWidget {
  const _TaqaCompletionDialogContent({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.eyebrow,
    required this.onDone,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final String? eyebrow;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final eyebrowText = eyebrow?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrowText.isNotEmpty) ...[
          Text(
            taqaUppercase(eyebrowText),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(18)),
        ],
        Container(
          width: TaqaUiScale.w(68),
          height: TaqaUiScale.w(68),
          decoration: BoxDecoration(
            color: TaqaUiColors.accent,
            borderRadius: TaqaUiScale.radius(15),
          ),
          child: Icon(
            Icons.check_rounded,
            size: TaqaUiScale.w(40),
            color: TaqaUiColors.charcoal,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(20)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(24),
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: TaqaUiColors.charcoal,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w400,
            height: 18 / 13,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: TaqaUiScale.h(24)),
        TaqaFilledButton(label: buttonLabel, onTap: onDone),
      ],
    );
  }
}
