import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_bulk_selection.dart';
import '../../services/calendar/calendar_food_commands.dart';
import '../../services/calendar/calendar_time_zone.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import 'calendar_details_sheet.dart';

class CalendarBulkSheet extends StatefulWidget {
  const CalendarBulkSheet({
    super.key,
    required this.userId,
    required this.date,
    this.references = const [],
  });
  final int userId;
  final DateTime date;
  final List<Map<String, dynamic>> references;
  @override
  State<CalendarBulkSheet> createState() => _CalendarBulkSheetState();
}

class _CalendarBulkSheetState extends State<CalendarBulkSheet> {
  final _selection = CalendarBulkSelection();
  List<CalendarFoodState> _states = [];
  PendingCalendarMove? _pending;
  bool _loading = true, _saving = false, _reloadRequired = false;
  String? _error, _zone;
  bool _manualZone = false;
  String _action = 'copy';
  final List<DateTime> _dates = [];
  final Map<String, int> _folds = {};
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  DateTime _previewNow = DateTime.now();
  String t(String key) => AppLocalizations.of(context).translate(key);

  String _destinationLabel(Map destination) {
    final zone = _pending?.request['timezone'] as String? ?? _zone ?? 'UTC';
    final at = CalendarTimeZone.inZone(
      DateTime.parse(destination['scheduled_at'] as String),
      zone,
    );
    return '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hms().format(at)} '
        '(UTC${CalendarTimeZone.offset(at)}) · ${t('calendar_copy_${destination['expected_status']}')}';
  }

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
        if (!pending.isBulk) {
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
      final states = <CalendarFoodState>[];
      // A failed read prevents partial select-all; stale intent survives reload.
      for (final ref in widget.references) {
        final state = await CalendarFoodCommands.fetchState(
          widget.userId,
          ref['kind'] as String,
          ref['id'] as int,
        );
        if (state != null && state.canBulk) states.add(state);
      }
      if (states.isEmpty) {
        throw const CalendarCommandError('calendar_bulk_unavailable');
      }
      var zone = _zone;
      if (zone == null) {
        try {
          zone = await CalendarTimeZone.deviceName();
          _manualZone = false;
        } catch (_) {
          _manualZone = true;
          /* Explicit choice. */
        }
      }
      if (!mounted) return;
      setState(() {
        if (_dates.isEmpty) {
          _dates.add(DateUtils.dateOnly(widget.date));
          final times =
              states.map((s) => s.scheduledAt).whereType<DateTime>().toList()
                ..sort();
          if (times.isNotEmpty && zone != null) {
            _time = TimeOfDay.fromDateTime(
              CalendarTimeZone.inZone(times.first, zone),
            );
          }
        }
        _states = states;
        _selection.retain(states);
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

  void _change(VoidCallback change) => setState(() {
    change();
    _error = null;
    _previewNow = DateTime.now();
  });

  List<DateTime> _candidates(DateTime date) => _zone == null
      ? []
      : CalendarTimeZone.candidates(date, _time.hour, _time.minute, _zone!);

  List<Map<String, dynamic>> _preview() {
    if (_action != 'delete' && _zone == null) {
      throw const CalendarCommandError('calendar_time_choose_zone');
    }
    final anchors = <DateTime>[];
    if (_action != 'delete') {
      for (final day in _dates) {
        final candidates = _candidates(day);
        if (candidates.isEmpty) {
          throw const CalendarCommandError('calendar_time_dst_gap');
        }
        final fold = candidates.length == 1 ? 0 : _folds[calendarDate(day)];
        if (fold == null) {
          throw const CalendarCommandError('calendar_time_dst_fold');
        }
        anchors.add(candidates[fold]);
      }
    }
    return _selection.entries(
      states: _states,
      action: _action,
      zone: _zone ?? 'UTC',
      anchors: anchors,
      previewNow: _previewNow,
    );
  }

  Future<void> _date([int? index]) async {
    final initial = index == null ? _dates.last : _dates[index];
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2000 ? initial.year : 2000),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (!mounted ||
        date == null ||
        _dates.asMap().entries.any(
          (e) => e.key != index && DateUtils.isSameDay(e.value, date),
        )) {
      return;
    }
    _change(() {
      if (index == null) {
        _dates.add(date);
      } else {
        _dates[index] = date;
      }
      _folds.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    List<Map<String, dynamic>> entries = [];
    if (_pending == null) {
      try {
        entries = _preview();
      } on CalendarCommandError catch (e) {
        setState(() => _error = e.messageKey);
        return;
      }
      if (_action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t('calendar_bulk_delete')),
            content: Text(t('calendar_bulk_delete_confirm')),
            actions: [
              TextButton(
                style: calendarActionStyle(context),
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('common_cancel')),
              ),
              TextButton(
                style: calendarActionStyle(context),
                onPressed: () => Navigator.pop(context, true),
                child: Text(t('calendar_bulk_delete')),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
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
        await CalendarFoodCommands.bulk(
          userId: widget.userId,
          action: _action,
          timezone: _zone ?? 'UTC',
          entries: entries,
          states: _states.where(_selection.contains).toList(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      PendingCalendarMove? pending;
      try {
        pending = await CalendarFoodCommands.pending(widget.userId);
      } catch (_) {
        /* Retain receipt. */
      }
      if (mounted) {
        setState(() {
          _pending = pending?.isBulk == true ? pending : null;
          _reloadRequired = e is CalendarCommandError && e.reload;
          _error = e is CalendarCommandError
              ? e.messageKey
              : 'calendar_time_uncertain';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRecipe() async {
    if (_saving) return;
    try {
      final entries = _selection.entries(
        states: _states,
        action: 'recipe',
        zone: 'UTC',
        anchors: [],
        previewNow: _previewNow,
      );
      setState(() => _saving = true);
      final saved = await showCalendarDetails(
        context,
        userId: widget.userId,
        action: 'recipe',
        date: widget.date,
        entries: entries,
      );
      if (saved && mounted) Navigator.pop(context, false);
    } on CalendarCommandError catch (e) {
      if (mounted) setState(() => _error = e.messageKey);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving && !_reloadRequired;
    List<Map<String, dynamic>> preview = [];
    String? previewError;
    if (_states.isNotEmpty && _pending == null) {
      try {
        preview = _preview();
      } on CalendarCommandError catch (e) {
        previewError = e.messageKey;
      }
    }
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('calendar_bulk_title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_pending != null) ...[
                  Text(t('calendar_time_pending_move')),
                  Text(_pending!.title),
                  Text(t('calendar_bulk_${_pending!.request['action']}')),
                  for (final dest in _pending!.destinations)
                    Text(_destinationLabel(dest)),
                ] else if (_states.isNotEmpty) ...[
                  Text(t('calendar_bulk_review')),
                  Text(
                    t(
                      'calendar_bulk_selected',
                    ).replaceAll('{count}', '${_selection.count}'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        style: calendarActionStyle(context),
                        onPressed: enabled
                            ? () => _change(() {
                                for (final s in _states) {
                                  _selection.selectWhole(s, true);
                                }
                              })
                            : null,
                        child: Text(t('calendar_bulk_all')),
                      ),
                      TextButton(
                        style: calendarActionStyle(context),
                        onPressed: enabled
                            ? () => _change(_selection.choices.clear)
                            : null,
                        child: Text(t('calendar_bulk_clear')),
                      ),
                    ],
                  ),
                  for (final s in _states)
                    Card(
                      child: Column(
                        children: [
                          CheckboxListTile(
                            key: ValueKey('bulk-parent-${s.kind}-${s.id}'),
                            title: Text(s.title),
                            subtitle: Text(t('calendar_copy_whole')),
                            tristate: true,
                            value: _selection.whole(s)
                                ? true
                                : (_selection.contains(s) ? null : false),
                            onChanged: enabled
                                ? (_) => _change(
                                    () => _selection.selectWhole(
                                      s,
                                      !_selection.whole(s),
                                    ),
                                  )
                                : null,
                          ),
                          if (s.items.isNotEmpty)
                            ExpansionTile(
                              title: Text(t('calendar_bulk_items')),
                              children: [
                                for (final item in s.items)
                                  CheckboxListTile(
                                    key: ValueKey(
                                      'bulk-item-${s.kind}-${s.id}-${CalendarBulkSelection.itemKey(s, item)}',
                                    ),
                                    title: Text(item['name']?.toString() ?? ''),
                                    subtitle: Text(
                                      '${item['calories'] ?? 0} kcal',
                                    ),
                                    value: _selection.itemSelected(
                                      s,
                                      CalendarBulkSelection.itemKey(s, item),
                                    ),
                                    onChanged: enabled
                                        ? (v) => _change(
                                            () => _selection.selectItem(
                                              s,
                                              CalendarBulkSelection.itemKey(
                                                s,
                                                item,
                                              ),
                                              v == true,
                                            ),
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (_selection.hasItems) Text(t('calendar_copy_item_totals')),
                  Text(
                    t('calendar_bulk_action'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_states.where(_selection.contains).isNotEmpty &&
                      _states
                          .where(_selection.contains)
                          .every((s) => s.canRecipe))
                    TextButton.icon(
                      style: calendarActionStyle(context),
                      onPressed: enabled ? _createRecipe : null,
                      icon: const Icon(Icons.restaurant_menu),
                      label: Text(t('calendar_details_recipe')),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final action in ['copy', 'reschedule', 'delete'])
                        ChoiceChip(
                          label: Text(t('calendar_bulk_$action')),
                          selected: _action == action,
                          onSelected: enabled
                              ? (_) => _change(() {
                                  _action = action;
                                  if (action == 'reschedule' &&
                                      _dates.length > 1) {
                                    _dates.removeRange(1, _dates.length);
                                  }
                                })
                              : null,
                        ),
                    ],
                  ),
                  if (_action != 'delete') ...[
                    Text(t('calendar_bulk_spacing')),
                    OutlinedButton(
                      style: calendarActionStyle(context),
                      onPressed: enabled
                          ? () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (mounted && time != null) {
                                _change(() {
                                  _time = time;
                                  _folds.clear();
                                });
                              }
                            }
                          : null,
                      child: Text(
                        '${t('calendar_bulk_first_time')}: ${_time.format(context)}',
                      ),
                    ),
                    if (_manualZone || _zone == null)
                      DropdownButtonFormField<String>(
                        initialValue: _zone,
                        isExpanded: true,
                        menuMaxHeight: 300,
                        decoration: InputDecoration(
                          labelText: t('calendar_time_zone'),
                        ),
                        items: CalendarTimeZone.names
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: enabled
                            ? (zone) => _change(() {
                                _zone = zone;
                                _folds.clear();
                              })
                            : null,
                      ),
                    for (var i = 0; i < _dates.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: calendarActionStyle(context),
                              onPressed: enabled ? () => _date(i) : null,
                              child: Text(calendarDate(_dates[i])),
                            ),
                          ),
                          if (_dates.length > 1)
                            IconButton(
                              tooltip: t('calendar_bulk_remove_date'),
                              onPressed: enabled
                                  ? () => _change(() => _dates.removeAt(i))
                                  : null,
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      if (_candidates(_dates[i]).length > 1) ...[
                        Text(t('calendar_time_dst_fold')),
                        for (var n = 0; n < _candidates(_dates[i]).length; n++)
                          ChoiceChip(
                            label: Text(
                              CalendarTimeZone.offset(
                                _candidates(_dates[i])[n],
                              ),
                            ),
                            selected: _folds[calendarDate(_dates[i])] == n,
                            onSelected: enabled
                                ? (_) => _change(
                                    () => _folds[calendarDate(_dates[i])] = n,
                                  )
                                : null,
                          ),
                      ],
                    ],
                    if (_action == 'copy' && _dates.length < 14)
                      TextButton(
                        style: calendarActionStyle(context),
                        onPressed: enabled ? () => _date() : null,
                        child: Text(t('calendar_copy_add_date')),
                      ),
                  ],
                  Text(
                    t('calendar_bulk_preview'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final entry in preview) ...[
                    Text(
                      _states
                          .firstWhere(
                            (s) =>
                                s.kind == entry['source']['kind'] &&
                                s.id == entry['source']['id'],
                          )
                          .title,
                    ),
                    if (_action == 'delete')
                      Text(t('calendar_bulk_delete_confirm')),
                    for (final dest in entry['destinations'] as List)
                      Text(_destinationLabel(dest)),
                  ],
                  if (previewError != null) Text(t(previewError)),
                ],
                if (_error != null) Text(t(_error!)),
                if (_reloadRequired ||
                    (!_loading && _states.isEmpty && _pending == null))
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: _saving ? null : _load,
                    child: Text(t('calendar_time_reload')),
                  ),
                if (!_loading && (_pending != null || _states.isNotEmpty))
                  FilledButton(
                    onPressed:
                        enabled && (_pending != null || previewError == null)
                        ? _save
                        : null,
                    child: Text(
                      t(
                        _pending != null
                            ? 'calendar_bulk_retry'
                            : 'calendar_bulk_confirm_$_action',
                      ),
                    ),
                  ),
                TextButton(
                  style: calendarActionStyle(context),
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(t('common_cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showCalendarBulkEditor(
  BuildContext context, {
  required int userId,
  required DateTime date,
  List<Map<String, dynamic>> references = const [],
}) async {
  if (await AccountStorage.getUserId() != userId || !context.mounted) {
    return false;
  }
  final saved =
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => CalendarBulkSheet(
          userId: userId,
          date: date,
          references: references,
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
        AppLocalizations.of(context).translate('calendar_bulk_saved'),
        type: AppToastType.success,
      );
    }
  } catch (_) {
    debugPrint('Calendar saved; confirmation display failed.');
  }
  return saved;
}
