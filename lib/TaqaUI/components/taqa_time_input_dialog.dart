import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_filled_button.dart';
import 'taqa_popup_guard.dart';
import 'taqa_value_dialog.dart';

/// Opens TAQA's keyboard-only time editor.
///
/// This intentionally avoids Material's platform time picker so its actions,
/// colors and input behavior stay consistent with the rest of TAQA UI.
Future<TimeOfDay?> showTaqaTimeInputDialog({
  required BuildContext context,
  required String title,
  required TimeOfDay initialTime,
  required String hourLabel,
  required String minuteLabel,
  required String invalidTimeMessage,
  required String cancelLabel,
  required String saveLabel,
}) {
  return TaqaPopupGuard.dialog<TimeOfDay>(
    context: context,
    barrierColor: context.taqaColors.scrim,
    builder: (_) => _TaqaTimeInputDialog(
      title: title,
      initialTime: initialTime,
      hourLabel: hourLabel,
      minuteLabel: minuteLabel,
      invalidTimeMessage: invalidTimeMessage,
      cancelLabel: cancelLabel,
      saveLabel: saveLabel,
    ),
  );
}

class _TaqaTimeInputDialog extends StatefulWidget {
  const _TaqaTimeInputDialog({
    required this.title,
    required this.initialTime,
    required this.hourLabel,
    required this.minuteLabel,
    required this.invalidTimeMessage,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final String title;
  final TimeOfDay initialTime;
  final String hourLabel;
  final String minuteLabel;
  final String invalidTimeMessage;
  final String cancelLabel;
  final String saveLabel;

  @override
  State<_TaqaTimeInputDialog> createState() => _TaqaTimeInputDialogState();
}

class _TaqaTimeInputDialogState extends State<_TaqaTimeInputDialog> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  final FocusNode _hourFocus = FocusNode();
  final FocusNode _minuteFocus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController(
      text: widget.initialTime.hour.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());
    if (hour == null || hour > 23 || minute == null || minute > 59) {
      setState(() => _error = widget.invalidTimeMessage);
      return;
    }
    Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: TaqaPopupDialog(
        bottomInset: bottomInset,
        onBackgroundTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(24)),
            Row(
              children: [
                Expanded(
                  child: _TimeNumberField(
                    controller: _hourController,
                    focusNode: _hourFocus,
                    label: widget.hourLabel,
                    onSubmitted: (_) => _minuteFocus.requestFocus(),
                  ),
                ),
                Padding(
                  padding: TaqaUiScale.symmetric(horizontal: 10),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(26),
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: _TimeNumberField(
                    controller: _minuteController,
                    focusNode: _minuteFocus,
                    label: widget.minuteLabel,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              SizedBox(height: TaqaUiScale.h(10)),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(12),
                  color: colors.danger,
                ),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(24)),
            Row(
              children: [
                Expanded(
                  child: TaqaTextActionButton(
                    label: widget.cancelLabel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(10)),
                Expanded(
                  child: TaqaFilledButton(
                    label: widget.saveLabel,
                    onTap: _submit,
                    height: 45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeNumberField extends StatelessWidget {
  const _TimeNumberField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.center,
      maxLength: 2,
      inputFormatters: const [_TwoDigitFormatter()],
      onTap: () => controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        fontSize: TaqaUiScale.sp(24),
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(8),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _TwoDigitFormatter extends TextInputFormatter {
  const _TwoDigitFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return RegExp(r'^\d{0,2}$').hasMatch(newValue.text) ? newValue : oldValue;
  }
}
