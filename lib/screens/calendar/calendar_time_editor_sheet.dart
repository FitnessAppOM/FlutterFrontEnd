import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_food_commands.dart';
import '../../services/calendar/calendar_time_zone.dart';
import '../../core/account_storage.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import 'calendar_copy_sheet.dart';
import 'calendar_bulk_sheet.dart';
import 'calendar_details_sheet.dart';

class CalendarTimeEditorSheet extends StatefulWidget {
  const CalendarTimeEditorSheet({
    super.key,
    required this.userId,
    required this.kind,
    required this.foodId,
  });
  final int userId;
  final String kind;
  final int foodId;

  @override
  State<CalendarTimeEditorSheet> createState() =>
      _CalendarTimeEditorSheetState();
}

class _CalendarTimeEditorSheetState extends State<CalendarTimeEditorSheet> {
  CalendarFoodState? _state;
  PendingCalendarMove? _pending;
  DateTime? _day;
  TimeOfDay? _time;
  String? _zone;
  bool _manualZone = false;
  int? _fold;
  bool _loading = true;
  bool _saving = false;
  bool _reloadRequired = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await CalendarFoodCommands.pending(widget.userId);
      if (pending != null) {
        if (pending.kind != widget.kind || pending.id != widget.foodId) {
          throw const CalendarCommandError('calendar_time_pending_move');
        }
        if (!mounted) return;
        setState(() {
          _pending = pending;
          _reloadRequired = false;
        });
        return;
      }
      final state = await CalendarFoodCommands.fetchState(
        widget.userId,
        widget.kind,
        widget.foodId,
      );
      if (state == null || !state.canEditTime) {
        throw const CalendarCommandError('calendar_time_unavailable');
      }
      String? zone = _zone;
      if (zone == null) {
        try {
          zone = await CalendarTimeZone.deviceName();
          _manualZone = false;
        } catch (_) {
          _manualZone = true;
          /* User selects a zone. */
        }
      }
      final clock = zone != null && state.scheduledAt != null
          ? CalendarTimeZone.inZone(state.scheduledAt!, zone)
          : null;
      if (!mounted) return;
      setState(() {
        _state = state;
        _pending = null;
        _zone = zone;
        // Preserve the stored logical date, including when travelling.
        _day ??= state.date;
        _time ??= clock == null
            ? const TimeOfDay(hour: 12, minute: 0)
            : TimeOfDay.fromDateTime(clock);
        _reloadRequired = false;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is CalendarCommandError
              ? e.messageKey
              : 'calendar_time_load_error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DateTime> get _candidates =>
      _day == null || _time == null || _zone == null
      ? []
      : CalendarTimeZone.candidates(_day!, _time!.hour, _time!.minute, _zone!);

  Future<void> _pickDate() async {
    final initial = _day!;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2000 ? initial.year : 2000),
      lastDate: DateTime(
        initial.year > DateTime.now().year + 10
            ? initial.year + 1
            : DateTime.now().year + 10,
      ),
    );
    if (mounted && selected != null) {
      setState(() {
        _day = selected;
        _fold = null;
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time!,
    );
    if (mounted && selected != null) {
      setState(() {
        _time = selected;
        _fold = null;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final choices = _candidates;
    DateTime? chosen;
    if (_pending == null) {
      if (_zone == null) {
        setState(() => _error = 'calendar_time_choose_zone');
        return;
      }
      if (choices.isEmpty) {
        setState(() => _error = 'calendar_time_dst_gap');
        return;
      }
      if (choices.length > 1 && _fold == null) {
        setState(() => _error = 'calendar_time_dst_fold');
        return;
      }
      chosen = choices[choices.length == 1 ? 0 : _fold!];
      if (widget.kind == 'meal' && chosen.isAfter(DateTime.now())) {
        setState(() => _error = 'calendar_time_future');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_pending != null) {
        await CalendarFoodCommands.retry(widget.userId);
      } else {
        await CalendarFoodCommands.move(
          userId: widget.userId,
          state: _state!,
          timestamp: CalendarTimeZone.timestamp(chosen!),
          timezone: _zone!,
          destination: _day!,
        );
      }
      if (!mounted) return;
      // A successful write remains successful even when the parent refresh fails.
      Navigator.of(context).pop(true);
    } catch (e) {
      PendingCalendarMove? pending;
      try {
        pending = await CalendarFoodCommands.pending(widget.userId);
      } catch (_) {
        /* Keep existing receipt. */
      }
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _error = e is CalendarCommandError
            ? e.messageKey
            : (pending != null
                  ? 'calendar_time_uncertain'
                  : 'calendar_time_load_error');
        _reloadRequired = e is CalendarCommandError && e.reload;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final choices = _candidates;
    final enabled =
        !_saving && !_loading && _pending == null && !_reloadRequired;
    final pending = _pending;
    String preview(DateTime instant) =>
        '${DateFormat.yMMMd(t.locale.languageCode).add_jm().format(instant)} (UTC${CalendarTimeZone.offset(instant)})';
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.translate('calendar_time_edit'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (pending != null) ...[
                Text(pending.title),
                Text(t.translate('calendar_time_uncertain')),
                Text(
                  '${DateFormat.yMMMd(t.locale.languageCode).format(pending.sourceDate)} → '
                  '${preview(CalendarTimeZone.inZone(DateTime.parse(pending.request['scheduled_at'] as String), pending.request['timezone'] as String))} '
                  '(${pending.request['timezone']})',
                ),
              ] else if (_state != null) ...[
                Text(_state!.title),
                Text(
                  t
                      .translate('calendar_time_source_date')
                      .replaceAll('{date}', calendarDate(_state!.date)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: calendarActionStyle(context),
                  onPressed: enabled ? _pickDate : null,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    DateFormat.yMMMd(t.locale.languageCode).format(_day!),
                  ),
                ),
                OutlinedButton.icon(
                  style: calendarActionStyle(context),
                  onPressed: enabled ? _pickTime : null,
                  icon: const Icon(Icons.schedule),
                  label: Text(_time!.format(context)),
                ),
                const SizedBox(height: 12),
                if (_manualZone || _zone == null)
                  DropdownButtonFormField<String>(
                    initialValue: _zone,
                    isExpanded: true,
                    menuMaxHeight: 300,
                    decoration: InputDecoration(
                      labelText: t.translate('calendar_time_zone'),
                    ),
                    items: CalendarTimeZone.names
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(
                              name.replaceAll('_', ' '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (value) => setState(() {
                            _zone = value;
                            _fold = null;
                            _error = null;
                          })
                        : null,
                  ),
                if (_zone == null)
                  Text(t.translate('calendar_time_choose_zone')),
                if (_zone != null && choices.isEmpty)
                  Text(t.translate('calendar_time_dst_gap')),
                if (choices.length > 1) ...[
                  Text(t.translate('calendar_time_dst_fold')),
                  for (var i = 0; i < choices.length; i++)
                    OutlinedButton(
                      style: calendarActionStyle(context),
                      onPressed: enabled
                          ? () => setState(() => _fold = i)
                          : null,
                      child: Text(
                        '${_fold == i ? '✓ ' : ''}UTC${CalendarTimeZone.offset(choices[i])}',
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  t.translate(
                    widget.kind == 'meal_plan'
                        ? 'calendar_time_plan_notice'
                        : 'calendar_time_meal_notice',
                  ),
                ),
                if (choices.length == 1 ||
                    (choices.length > 1 && _fold != null))
                  Text(
                    '${DateFormat.yMMMd(t.locale.languageCode).format(_state!.date)} → '
                    '${preview(choices[choices.length == 1 ? 0 : _fold!])}',
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    t.translate(_error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_reloadRequired ||
                  (!_loading && _state == null && pending == null))
                FilledButton(
                  onPressed: _saving ? null : _load,
                  child: Text(t.translate('calendar_time_reload_button')),
                )
              else if (!_loading)
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          t.translate(
                            pending == null
                                ? 'common_save'
                                : 'calendar_time_retry',
                          ),
                        ),
                ),
              TextButton(
                style: calendarActionStyle(context),
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(t.translate('common_cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showCalendarTimeEditor(
  BuildContext context, {
  required int userId,
  required String kind,
  required int foodId,
  bool copy = false,
}) async {
  if (await AccountStorage.getUserId() != userId || !context.mounted) {
    return false;
  }
  final pending = await CalendarFoodCommands.pending(userId);
  if (!context.mounted) return false;
  if (pending?.isDetails == true) {
    return showCalendarDetails(
      context,
      userId: userId,
      action: pending!.action,
      date: pending.sourceDate,
    );
  }
  if (pending?.isBulk == true) {
    return showCalendarBulkEditor(
      context,
      userId: userId,
      date: pending!.sourceDate,
    );
  }
  final saved =
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => copy
            ? CalendarCopySheet(userId: userId, kind: kind, foodId: foodId)
            : CalendarTimeEditorSheet(
                userId: userId,
                kind: kind,
                foodId: foodId,
              ),
      ) ??
      false;
  try {
    if (saved &&
        context.mounted &&
        await AccountStorage.getUserId() == userId &&
        context.mounted) {
      AppToast.show(
        context,
        AppLocalizations.of(
          context,
        ).translate(copy ? 'calendar_copy_saved' : 'calendar_time_saved'),
        type: AppToastType.success,
      );
    }
  } catch (_) {
    debugPrint('Calendar saved; confirmation display failed.');
  }
  return saved;
}
