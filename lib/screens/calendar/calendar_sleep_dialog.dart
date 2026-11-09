import 'package:flutter/material.dart';
import 'calendar_action_style.dart';

import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../localization/app_localizations.dart';

class CalendarSleepDialog extends StatefulWidget {
  const CalendarSleepDialog({super.key, required this.initialMinutes});

  final int initialMinutes;

  @override
  State<CalendarSleepDialog> createState() => _CalendarSleepDialogState();
}

class _CalendarSleepDialogState extends State<CalendarSleepDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialMinutes > 0
          ? (widget.initialMinutes / 60).toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parseHours(String text) {
    var normalized = text.trim().replaceAll(',', '.').replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      normalized = normalized
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    return double.tryParse(normalized);
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_parseHours(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return TaqaPopupDialog(
      bottomInset: MediaQuery.viewInsetsOf(context).bottom,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.translate('sleep_add_dialog_title'),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TaqaUiScale.sp(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: t.translate('daily_journal_sleep_hours_label'),
                hintText: t.translate('daily_journal_sleep_hours_hint'),
                errorMaxLines: 3,
              ),
              validator: (text) {
                final hours = _parseHours(text ?? '');
                return hours == null ||
                        !hours.isFinite ||
                        hours < 1 / 60 ||
                        hours > 24
                    ? t.translate('day_timeline_invalid_sleep')
                    : null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            Row(
              children: [
                TextButton(
                  style: calendarActionStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.translate('common_cancel')),
                ),
                SizedBox(width: TaqaUiScale.w(12)),
                Expanded(
                  child: TaqaFilledButton(
                    label: t.translate('common_save'),
                    onTap: _save,
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
