import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_food_commands.dart';
import '../../services/calendar/calendar_portion_math.dart';
import '../../services/calendar/calendar_time_zone.dart';
import '../../TaqaUI/components/taqa_toast.dart';

class CalendarDetailsSheet extends StatefulWidget {
  const CalendarDetailsSheet({
    super.key,
    required this.userId,
    required this.action,
    required this.date,
    this.entries = const [],
    this.kind,
    this.foodId,
    this.itemId,
    this.itemKey,
    this.initialTime,
  });
  final int userId;
  final String action;
  final DateTime date;
  final TimeOfDay? initialTime;
  final List<Map<String, dynamic>> entries;
  final String? kind, itemKey;
  final int? foodId, itemId;
  @override
  State<CalendarDetailsSheet> createState() => _CalendarDetailsSheetState();
}

class _CalendarDetailsSheetState extends State<CalendarDetailsSheet> {
  final _name = TextEditingController(),
      _servings = TextEditingController(text: '1'),
      _weight = TextEditingController(),
      _quantity = TextEditingController(text: '1');
  final _macros = {
    for (final k in CalendarPortionMath.macros) k: TextEditingController(),
  };
  List<CalendarFoodState> _states = [];
  List<Map<String, dynamic>> _recipes = [];
  Map<String, dynamic>? _recipe, _item;
  PendingCalendarMove? _pending;
  String? _error, _zone;
  bool _manualZone = false;
  bool _loading = true,
      _saving = false,
      _reload = false,
      _ack = false,
      _clearOverrides = false,
      _custom = false;
  int _generation = 0;
  DateTime? _day;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  int? _fold;
  DateTime _previewNow = DateTime.now();
  String t(String key) => AppLocalizations.of(context).translate(key);
  bool get _create => widget.action == 'recipe';
  bool get _log => widget.action == 'recipe-log';
  bool get _hasOverrides =>
      _states.any((s) => s.overrides?.any((v) => v != null) ?? false);

  @override
  void initState() {
    super.initState();
    _day = DateUtils.dateOnly(widget.date);
    _time = widget.initialTime ?? _time;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _servings, _weight, _quantity, ..._macros.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load([int? recipeId]) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await CalendarFoodCommands.pending(widget.userId);
      if (pending != null) {
        if (!pending.isDetails) {
          throw const CalendarCommandError('calendar_time_pending_move');
        }
        if (mounted && generation == _generation) {
          setState(() {
            _pending = pending;
            _reload = false;
          });
        }
        return;
      }
      if (_log) {
        final list = await CalendarFoodCommands.readRecipes(widget.userId);
        if (list == null) {
          throw const CalendarCommandError('calendar_details_unavailable');
        }
        final recipes = (list['recipes'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final id =
            recipeId ??
            _recipe?['id'] as int? ??
            (recipes.isEmpty ? null : recipes.first['id'] as int);
        final recipe = id == null
            ? null
            : await CalendarFoodCommands.readRecipes(widget.userId, id);
        String? zone = _zone;
        if (zone == null) {
          try {
            zone = await CalendarTimeZone.deviceName();
            _manualZone = false;
          } catch (_) {
            _manualZone = true;
            /* Explicit choice. */
          }
        }
        if (!mounted || generation != _generation) return;
        setState(() {
          _recipes = recipes;
          _recipe = recipe;
          _zone = zone;
        });
      } else {
        final references = _create
            ? widget.entries.map((e) => e['source'] as Map).toList()
            : [
                <String, dynamic>{'kind': widget.kind, 'id': widget.foodId},
              ];
        final states = <CalendarFoodState>[];
        for (final ref in references) {
          final state = await CalendarFoodCommands.fetchState(
            widget.userId,
            ref['kind'] as String,
            ref['id'] as int,
          );
          if (state == null ||
              (_create ? !state.canRecipe : !state.canEditContents)) {
            throw const CalendarCommandError('calendar_details_unavailable');
          }
          states.add(state);
        }
        if (!mounted || generation != _generation) return;
        if (states.isEmpty) {
          throw const CalendarCommandError('calendar_details_unavailable');
        }
        _states = states;
        if (!_create) {
          final key = widget.kind == 'meal' ? 'id' : 'item_key';
          final id = widget.kind == 'meal'
              ? '${widget.itemId}'
              : widget.itemKey;
          _item = states.single.items
              .where((i) => '${i[key]}' == id)
              .firstOrNull;
          if (_item == null) {
            throw const CalendarCommandError('calendar_details_unavailable');
          }
          _updateMacros();
        }
      }
      if (mounted && generation == _generation) {
        setState(() {
          _pending = null;
          _reload = false;
          _previewNow = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e is CalendarCommandError
              ? e.messageKey
              : 'calendar_time_load_error';
          _reload = true;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> _selectedItems() {
    final items = <Map<String, dynamic>>[];
    for (var n = 0; n < _states.length; n++) {
      final entry = widget.entries[n];
      final ids = (entry['item_ids'] ?? entry['item_keys']) as List?;
      final key = _states[n].kind == 'meal' ? 'id' : 'item_key';
      final selected = _states[n].items
          .where(
            (i) => ids == null || ids.map((id) => '$id').contains('${i[key]}'),
          )
          .toList();
      if (ids != null && selected.length != ids.length) {
        throw const CalendarCommandError('calendar_recipe_reselect');
      }
      items.addAll(selected);
    }
    return items;
  }

  void _updateMacros() {
    if (_item == null || _custom) return;
    final factor = CalendarPortionMath.units(_quantity.text);
    if (factor == null || factor <= 0 || factor > 100000) return;
    for (final k in _macros.keys) {
      _macros[k]!.text =
          '${CalendarPortionMath.rounded((_item![k] as num?) ?? 0, factor, 1000)}';
    }
  }

  List<DateTime> get _candidates => _zone == null
      ? []
      : CalendarTimeZone.candidates(_day!, _time.hour, _time.minute, _zone!);
  DateTime? get _instant => _candidates.length == 1
      ? _candidates.single
      : (_fold == null ? null : _candidates[_fold!]);

  Map<String, dynamic> _request() {
    if (_create) {
      final servings = CalendarPortionMath.units(_servings.text);
      final weight = _weight.text.trim().isEmpty
          ? null
          : double.tryParse(_weight.text);
      final items = _selectedItems();
      if (_name.text.trim().isEmpty ||
          _name.text.trim().length > 200 ||
          servings == null ||
          servings <= 0 ||
          (!_ack) ||
          items.isEmpty ||
          items.length > 100 ||
          (_weight.text.trim().isNotEmpty &&
              (weight == null ||
                  !weight.isFinite ||
                  weight <= 0 ||
                  weight > 1000000 ||
                  !RegExp(
                    r'^\d+(\.\d{1,2})?$',
                  ).hasMatch(_weight.text.trim())))) {
        throw const CalendarCommandError('calendar_recipe_invalid');
      }
      return {
        'name': _name.text.trim(),
        'servings': _servings.text.trim(),
        'prepared_weight_g': weight,
        'nutrition_policy': 'item_totals',
        'entries': [
          for (var i = 0; i < _states.length; i++)
            {
              ...widget.entries[i],
              'source': _states[i].source,
              'destinations': [],
            },
        ],
      };
    }
    if (_log) {
      final servings = CalendarPortionMath.units(_servings.text);
      if (_recipe == null || servings == null || servings <= 0) {
        throw const CalendarCommandError('calendar_recipe_invalid');
      }
      if (_zone == null) {
        throw const CalendarCommandError('calendar_time_choose_zone');
      }
      if (_candidates.isEmpty) {
        throw const CalendarCommandError('calendar_time_dst_gap');
      }
      if (_instant == null) {
        throw const CalendarCommandError('calendar_time_dst_fold');
      }
      return {
        'recipe': {'id': _recipe!['id'], 'revision': _recipe!['revision']},
        'servings': _servings.text.trim(),
        'timezone': _zone,
        'destination': {
          'scheduled_date': calendarDate(_day!),
          'scheduled_at': CalendarTimeZone.timestamp(_instant!),
          'expected_status': _instant!.isAfter(_previewNow)
              ? 'planned'
              : 'logged',
        },
      };
    }
    final factor = CalendarPortionMath.units(_quantity.text);
    final nutrition = {
      for (final k in _macros.keys) k: int.tryParse(_macros[k]!.text),
    };
    if (factor == null ||
        factor <= 0 ||
        factor > 100000 ||
        (_custom &&
            nutrition.values.any((n) => n == null || n < 0 || n > 1000000))) {
      throw const CalendarCommandError('calendar_item_invalid');
    }
    return {
      'source': _states.single.source,
      if (widget.kind == 'meal')
        'item_id': widget.itemId
      else
        'item_key': widget.itemKey,
      'quantity_multiplier': _quantity.text.trim(),
      if (_custom) 'nutrition': nutrition,
      'override_policy': _clearOverrides ? 'clear' : 'preserve',
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    Map<String, dynamic> request = {};
    try {
      if (_pending == null) request = _request();
    } on CalendarCommandError catch (e) {
      setState(() => _error = e.messageKey);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_pending != null) {
        await CalendarFoodCommands.retry(widget.userId);
      } else {
        await CalendarFoodCommands.details(
          userId: widget.userId,
          action: widget.action,
          request: request,
          title: _create
              ? _name.text.trim()
              : (_log ? '${_recipe!['name']}' : '${_item!['name']}'),
          date: widget.date,
          states: _states,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      PendingCalendarMove? pending = _pending;
      try {
        pending = await CalendarFoodCommands.pending(widget.userId);
      } catch (_) {
        /* Keep the durable receipt for recovery. */
      }
      if (mounted) {
        setState(() {
          _pending = pending?.isDetails == true ? pending : null;
          _error = e is CalendarCommandError
              ? e.messageKey
              : 'calendar_time_uncertain';
          _reload = e is CalendarCommandError && e.reload;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _nutrition(Map<String, dynamic> values) => CalendarPortionMath.macros
      .map((k) => '${t('calendar_details_$k')}: ${values[k] ?? '—'}')
      .join(' · ');
  Widget _number(
    TextEditingController controller,
    String label, {
    VoidCallback? onChanged,
  }) => TextField(
    controller: controller,
    enabled: !_saving && !_reload,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: t(label)),
    onChanged: (_) => setState(() {
      onChanged?.call();
      _error = null;
    }),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving && !_reload;
    List<Map<String, dynamic>> items = [];
    String? selectionError;
    if (_create && _states.isNotEmpty) {
      try {
        items = _selectedItems();
      } on CalendarCommandError catch (e) {
        selectionError = e.messageKey;
      }
    }
    final servings = CalendarPortionMath.units(_servings.text);
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
                  t(
                    _pending != null
                        ? 'calendar_details_retry'
                        : 'calendar_details_${widget.action}',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_pending != null) ...[
                  Text(_pending!.title),
                  Text(t('calendar_details_${_pending!.action}')),
                  Text(t('calendar_time_pending_move')),
                  if (_pending!.request['servings'] != null)
                    Text(
                      '${t('calendar_recipe_servings')}: ${_pending!.request['servings']}',
                    ),
                  if (_pending!.request['quantity_multiplier'] != null)
                    Text(
                      '${t('calendar_item_multiplier')}: ${_pending!.request['quantity_multiplier']}',
                    ),
                  for (final d in _pending!.destinations)
                    Text(
                      '${d['scheduled_date']} · ${t('calendar_copy_${d['expected_status']}')}',
                    ),
                ] else if (_create && _states.isNotEmpty) ...[
                  TextField(
                    controller: _name,
                    enabled: enabled,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: t('calendar_recipe_name'),
                    ),
                  ),
                  _number(_servings, 'calendar_recipe_batch_servings'),
                  _number(_weight, 'calendar_recipe_weight'),
                  Text(
                    '${t('calendar_recipe_batch')}: ${_nutrition(CalendarPortionMath.totals(items, 1, 1))}',
                  ),
                  if (servings != null && servings > 0)
                    Text(
                      '${t('calendar_recipe_per_serving')}: ${_nutrition(CalendarPortionMath.totals(items, 1000, servings))}',
                    ),
                  if (servings != null &&
                      servings > 0 &&
                      double.tryParse(_weight.text) != null)
                    Text(
                      '${t('calendar_recipe_weight_per_serving')}: ${(double.parse(_weight.text) * 1000 / servings).toStringAsFixed(2)} g',
                    ),
                  if (_hasOverrides) ...[
                    Text(t('calendar_recipe_overrides')),
                    for (final s in _states.where(
                      (s) => s.overrides?.any((v) => v != null) ?? false,
                    ))
                      Text(
                        '${s.title}: ${_nutrition({for (var i = 0; i < 4; i++) CalendarPortionMath.macros[i]: s.overrides![i]})}',
                      ),
                  ],
                  CheckboxListTile(
                    value: _ack,
                    onChanged: enabled
                        ? (v) => setState(() => _ack = v == true)
                        : null,
                    title: Text(t('calendar_recipe_item_policy')),
                  ),
                  for (final item in items)
                    Text(
                      '${item['name']} · ${item['grams'] ?? t('calendar_recipe_unknown_weight')}',
                    ),
                ] else if (_log) ...[
                  if (_recipes.isEmpty) Text(t('calendar_recipe_empty')),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_recipe?['id']),
                    initialValue: _recipes.any((r) => r['id'] == _recipe?['id'])
                        ? (_recipe?['id'] as int?)
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('calendar_recipe_name'),
                    ),
                    items: _recipes
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text(
                              r['name']?.toString() ??
                                  t('calendar_recipe_name'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enabled ? (id) => _load(id) : null,
                  ),
                  _number(_servings, 'calendar_recipe_servings'),
                  if (_recipe != null) ...[
                    Text(
                      '${t('calendar_recipe_batch_servings')}: ${_recipe!['servings']}',
                    ),
                    if (servings != null && servings > 0)
                      Text(
                        _nutrition(
                          CalendarPortionMath.totals(
                            (_recipe!['items'] as List)
                                .map((i) => Map<String, dynamic>.from(i as Map))
                                .toList(),
                            servings,
                            CalendarPortionMath.units(
                              '${_recipe!['servings']}',
                            )!,
                          ),
                        ),
                      ),
                  ],
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: enabled
                        ? () async {
                            final day = await showDatePicker(
                              context: context,
                              initialDate: _day!,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(DateTime.now().year + 10),
                            );
                            if (mounted && day != null) {
                              setState(() {
                                _day = day;
                                _fold = null;
                                _previewNow = DateTime.now();
                              });
                            }
                          }
                        : null,
                    child: Text(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(_day!),
                    ),
                  ),
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: enabled
                        ? () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _time,
                            );
                            if (mounted && time != null) {
                              setState(() {
                                _time = time;
                                _fold = null;
                                _previewNow = DateTime.now();
                              });
                            }
                          }
                        : null,
                    child: Text(_time.format(context)),
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
                            (zone) => DropdownMenuItem(
                              value: zone,
                              child: Text(
                                zone,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: enabled
                          ? (zone) => setState(() {
                              _zone = zone;
                              _fold = null;
                              _previewNow = DateTime.now();
                            })
                          : null,
                    ),
                  if (_candidates.length > 1) ...[
                    Text(t('calendar_time_dst_fold')),
                    for (var i = 0; i < _candidates.length; i++)
                      ChoiceChip(
                        label: Text(CalendarTimeZone.offset(_candidates[i])),
                        selected: _fold == i,
                        onSelected: enabled
                            ? (_) => setState(() {
                                _fold = i;
                                _previewNow = DateTime.now();
                              })
                            : null,
                      ),
                  ],
                  if (_zone != null && _candidates.isEmpty)
                    Text(t('calendar_time_dst_gap')),
                  if (_instant != null)
                    Text(
                      '${t('calendar_copy_${_instant!.isAfter(_previewNow) ? 'planned' : 'logged'}')} · UTC${CalendarTimeZone.offset(_instant!)}',
                    ),
                ] else if (_item != null) ...[
                  Text('${_item!['name']}'),
                  _number(
                    _quantity,
                    'calendar_item_multiplier',
                    onChanged: _updateMacros,
                  ),
                  Text(t('calendar_item_quantity_help')),
                  if (_item!['grams'] == null)
                    Text(t('calendar_recipe_unknown_weight')),
                  SwitchListTile(
                    value: _custom,
                    onChanged: enabled
                        ? (v) => setState(() {
                            _custom = v;
                            _updateMacros();
                          })
                        : null,
                    title: Text(t('calendar_item_custom')),
                  ),
                  if (_custom)
                    for (final k in _macros.keys)
                      _number(_macros[k]!, 'calendar_details_$k')
                  else
                    Text(
                      _nutrition({
                        for (final k in _macros.keys) k: _macros[k]!.text,
                      }),
                    ),
                  if (_hasOverrides) ...[
                    Text(t('calendar_item_override_help')),
                    SwitchListTile(
                      value: _clearOverrides,
                      onChanged: enabled
                          ? (v) => setState(() => _clearOverrides = v)
                          : null,
                      title: Text(t('calendar_item_clear_overrides')),
                    ),
                    Text(
                      t(
                        _clearOverrides
                            ? 'calendar_item_use_items'
                            : 'calendar_item_keep_overrides',
                      ),
                    ),
                  ],
                ],
                if (selectionError != null) Text(t(selectionError)),
                if (_error != null) Text(t(_error!)),
                if (_reload)
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: _saving ? null : _load,
                    child: Text(t('calendar_time_reload')),
                  ),
                if (!_loading)
                  FilledButton(
                    onPressed:
                        enabled &&
                            selectionError == null &&
                            (_pending != null ||
                                (_create
                                    ? _states.isNotEmpty
                                    : (_log ? _recipe != null : _item != null)))
                        ? _save
                        : null,
                    child: Text(
                      t(
                        _pending == null
                            ? 'common_save'
                            : 'calendar_details_retry',
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

Future<bool> showCalendarDetails(
  BuildContext context, {
  required int userId,
  required String action,
  required DateTime date,
  List<Map<String, dynamic>> entries = const [],
  String? kind,
  int? foodId,
  int? itemId,
  String? itemKey,
  TimeOfDay? initialTime,
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
        builder: (_) => CalendarDetailsSheet(
          userId: userId,
          action: action,
          date: date,
          entries: entries,
          kind: kind,
          foodId: foodId,
          itemId: itemId,
          itemKey: itemKey,
          initialTime: initialTime,
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
        AppLocalizations.of(context).translate('calendar_details_saved'),
        type: AppToastType.success,
      );
    }
  } catch (_) {
    debugPrint('Calendar saved; confirmation display failed.');
  }
  return saved;
}
