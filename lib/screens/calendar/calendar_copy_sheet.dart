import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_food_commands.dart';
import '../../services/calendar/calendar_time_zone.dart';

class CalendarCopySheet extends StatefulWidget {
  const CalendarCopySheet({
    super.key,
    required this.userId,
    required this.kind,
    required this.foodId,
  });
  final int userId;
  final String kind;
  final int foodId;
  @override
  State<CalendarCopySheet> createState() => _CalendarCopySheetState();
}

class _CalendarCopySheetState extends State<CalendarCopySheet> {
  CalendarFoodState? _state;
  PendingCalendarMove? _pending;
  bool _loading = true, _saving = false, _reloadRequired = false, _whole = true;
  String? _error, _zone;
  bool _manualZone = false;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  final List<DateTime> _dates = [];
  final Map<String, int> _folds = {};
  final Set<String> _selected = {};
  DateTime _previewNow = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _itemId(Map<String, dynamic> item) =>
      '${item[widget.kind == 'meal' ? 'id' : 'item_key']}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await CalendarFoodCommands.pending(widget.userId);
      if (pending != null) {
        if (!pending.isCopy ||
            pending.kind != widget.kind ||
            pending.id != widget.foodId) {
          throw const CalendarCommandError('calendar_time_pending_move');
        }
        if (mounted) {
          setState(() {
            _pending = pending;
            _reloadRequired = false;
          });
        }
        return;
      }
      final state = await CalendarFoodCommands.fetchState(
        widget.userId,
        widget.kind,
        widget.foodId,
      );
      if (state == null || !state.canCopy) {
        throw const CalendarCommandError('calendar_copy_unavailable');
      }
      String? zone = _zone;
      if (zone == null) {
        try {
          zone = await CalendarTimeZone.deviceName();
          _manualZone = false;
        } catch (_) {
          _manualZone = true;
          /* Explicit selection required. */
        }
      }
      if (!mounted) return;
      setState(() {
        if (_state == null) {
          if (zone != null && state.scheduledAt != null) {
            _time = TimeOfDay.fromDateTime(
              CalendarTimeZone.inZone(state.scheduledAt!, zone),
            );
          }
          final now = zone == null
              ? DateTime.now()
              : CalendarTimeZone.inZone(DateTime.now(), zone);
          _dates.add(DateUtils.dateOnly(now));
          _selected.addAll(state.items.map(_itemId));
        } else {
          _selected.retainAll(state.items.map(_itemId));
        }
        _state = state;
        _zone = zone;
        _pending = null;
        _reloadRequired = false;
        _previewNow = DateTime.now();
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

  List<DateTime> _candidates(DateTime day) => _zone == null
      ? []
      : CalendarTimeZone.candidates(day, _time.hour, _time.minute, _zone!);
  DateTime? _instant(DateTime day) {
    final values = _candidates(day);
    if (values.length == 1) return values.single;
    final index = _folds[calendarDate(day)];
    return index != null && index < values.length ? values[index] : null;
  }

  String _status(DateTime instant) =>
      instant.isAfter(_previewNow) ? 'planned' : 'logged';

  Future<void> _pickDate([int? index]) async {
    final initial = index == null ? _dates.last : _dates[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2000 ? initial.year : 2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (!mounted || picked == null) return;
    if (_dates.asMap().entries.any(
      (e) => e.key != index && DateUtils.isSameDay(e.value, picked),
    )) {
      return;
    }
    setState(() {
      if (index == null) {
        _dates.add(picked);
      } else {
        _dates[index] = picked;
      }
      _folds.clear();
      _previewNow = DateTime.now();
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (mounted && picked != null) {
      setState(() {
        _time = picked;
        _folds.clear();
        _previewNow = DateTime.now();
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_pending == null) {
      String? error;
      if (_zone == null) {
        error = 'calendar_time_choose_zone';
      } else if (_dates.any((d) => _candidates(d).isEmpty)) {
        error = 'calendar_time_dst_gap';
      } else if (_dates.any((d) => _instant(d) == null)) {
        error = 'calendar_time_dst_fold';
      } else if (!_whole && (_selected.isEmpty || _selected.length > 100)) {
        error = 'calendar_copy_select_food';
      }
      if (error != null) {
        setState(() => _error = error);
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
        await CalendarFoodCommands.copy(
          userId: widget.userId,
          state: _state!,
          timezone: _zone!,
          destinations: _dates
              .map(
                (day) => {
                  'scheduled_date': calendarDate(day),
                  'scheduled_at': CalendarTimeZone.timestamp(_instant(day)!),
                  'expected_status': _status(_instant(day)!),
                },
              )
              .toList(),
          itemIds: !_whole && widget.kind == 'meal'
              ? _selected.map(int.parse).toList()
              : null,
          itemKeys: !_whole && widget.kind == 'meal_plan'
              ? _selected.toList()
              : null,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      PendingCalendarMove? pending;
      try {
        pending = await CalendarFoodCommands.pending(widget.userId);
      } catch (_) {
        /* Keep durable receipt. */
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
    final enabled =
        !_loading && !_saving && !_reloadRequired && _pending == null;
    final pending = _pending;
    String dateLabel(DateTime d) =>
        DateFormat.yMMMd(t.locale.languageCode).format(d);
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
                t.translate('calendar_copy_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (pending != null) ...[
                Text(pending.title),
                Text(t.translate('calendar_time_uncertain')),
                Text(pending.request['timezone'] as String),
                for (final destination in pending.destinations)
                  Text(
                    '${dateLabel(DateTime.parse(destination['scheduled_date'] as String))} · '
                    '${DateFormat.jm(t.locale.languageCode).format(CalendarTimeZone.inZone(DateTime.parse(destination['scheduled_at'] as String), pending.request['timezone'] as String))} · '
                    '${t.translate(destination['expected_status'] == 'logged' ? 'calendar_copy_logged' : 'calendar_copy_planned')}',
                  ),
              ] else if (_state != null) ...[
                Text(_state!.title),
                Text(t.translate('calendar_copy_source_unchanged')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.translate('calendar_copy_whole')),
                  value: _whole,
                  onChanged: enabled && _state!.items.isNotEmpty
                      ? (v) => setState(() => _whole = v)
                      : null,
                ),
                if (!_whole) ...[
                  Text(t.translate('calendar_copy_item_totals')),
                  for (final item in _state!.items)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['name']?.toString() ?? ''),
                      subtitle: Text('${item['calories'] ?? 0} kcal'),
                      value: _selected.contains(_itemId(item)),
                      onChanged: enabled
                          ? (v) => setState(() {
                              if (v == true) {
                                _selected.add(_itemId(item));
                              } else {
                                _selected.remove(_itemId(item));
                              }
                            })
                          : null,
                    ),
                ],
                OutlinedButton(
                  style: calendarActionStyle(context),
                  onPressed: enabled
                      ? () => setState(() {
                          final now = _zone == null
                              ? DateTime.now()
                              : CalendarTimeZone.inZone(DateTime.now(), _zone!);
                          _dates
                            ..clear()
                            ..add(DateUtils.dateOnly(now));
                          _folds.clear();
                          _previewNow = DateTime.now();
                        })
                      : null,
                  child: Text(t.translate('calendar_copy_today')),
                ),
                OutlinedButton.icon(
                  style: calendarActionStyle(context),
                  onPressed: enabled ? _pickTime : null,
                  icon: const Icon(Icons.schedule),
                  label: Text(_time.format(context)),
                ),
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
                            _folds.clear();
                            _previewNow = DateTime.now();
                          })
                        : null,
                  ),
                if (_zone == null)
                  Text(t.translate('calendar_time_choose_zone')),
                for (var i = 0; i < _dates.length; i++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: Text(dateLabel(_dates[i])),
                    onTap: enabled ? () => _pickDate(i) : null,
                    subtitle: Text(
                      _instant(_dates[i]) == null
                          ? t.translate(
                              _zone == null
                                  ? 'calendar_time_choose_zone'
                                  : _candidates(_dates[i]).isEmpty
                                  ? 'calendar_time_dst_gap'
                                  : 'calendar_time_dst_fold',
                            )
                          : '${t.translate(_status(_instant(_dates[i])!) == 'logged' ? 'calendar_copy_logged' : 'calendar_copy_planned')} '
                                '(UTC${CalendarTimeZone.offset(_instant(_dates[i])!)})',
                    ),
                    trailing: _dates.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: enabled
                                ? () => setState(() => _dates.removeAt(i))
                                : null,
                          )
                        : null,
                  ),
                  if (_candidates(_dates[i]).length > 1)
                    for (var j = 0; j < _candidates(_dates[i]).length; j++)
                      OutlinedButton(
                        style: calendarActionStyle(context),
                        onPressed: enabled
                            ? () => setState(
                                () => _folds[calendarDate(_dates[i])] = j,
                              )
                            : null,
                        child: Text(
                          '${_folds[calendarDate(_dates[i])] == j ? '✓ ' : ''}UTC${CalendarTimeZone.offset(_candidates(_dates[i])[j])}',
                        ),
                      ),
                ],
                if (_dates.length < 14)
                  TextButton.icon(
                    style: calendarActionStyle(context),
                    onPressed: enabled ? () => _pickDate() : null,
                    icon: const Icon(Icons.add),
                    label: Text(t.translate('calendar_copy_add_date')),
                  ),
                Text(t.translate('calendar_copy_preview_notice')),
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
                                ? 'calendar_copy_confirm'
                                : 'calendar_copy_retry',
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
