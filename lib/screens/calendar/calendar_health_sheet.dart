import 'package:flutter/material.dart';
import 'calendar_action_style.dart';
import 'package:intl/intl.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_food_commands.dart';
import '../../services/calendar/calendar_health_api.dart';
import '../../services/calendar/calendar_time_zone.dart';

Future<bool?> showCalendarHealth(
  BuildContext context, {
  required int userId,
  required DateTime date,
  String kind = 'activity',
  int? hour,
  Map<String, dynamic>? session,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => CalendarHealthSheet(
    userId: userId,
    date: date,
    kind: kind,
    hour: hour,
    session: session,
  ),
);

class CalendarHealthSheet extends StatefulWidget {
  const CalendarHealthSheet({
    super.key,
    required this.userId,
    required this.date,
    this.kind = 'activity',
    this.hour,
    this.session,
  });
  final int userId;
  final DateTime date;
  final String kind;
  final int? hour;
  final Map<String, dynamic>? session;
  @override
  State<CalendarHealthSheet> createState() => _CalendarHealthSheetState();
}

class _CalendarHealthSheetState extends State<CalendarHealthSheet> {
  final _distance = TextEditingController();
  Map<String, dynamic>? _pending, _source;
  late DateTime _startDay, _endDay;
  TimeOfDay _start = const TimeOfDay(hour: 12, minute: 0),
      _end = const TimeOfDay(hour: 13, minute: 0);
  String _zone = 'UTC', _activity = 'walk', _sleep = 'main';
  String? _error;
  bool _loading = true, _saving = false, _reload = false, _formReady = false;
  int? _startFold, _endFold;
  int _startSecond = 0, _endSecond = 0;
  bool _recovering = false, _zoneConfirmed = true;
  bool _manualZone = false;
  String t(String key) => AppLocalizations.of(context).translate(key);
  bool get _isSleep => widget.kind == 'sleep';

  @override
  void initState() {
    super.initState();
    AccountStorage.accountChange.addListener(_accountChanged);
    _load();
  }

  @override
  void dispose() {
    AccountStorage.accountChange.removeListener(_accountChanged);
    _distance.dispose();
    super.dispose();
  }

  Future<void> _accountChanged() async {
    if (await AccountStorage.getUserId() != widget.userId && mounted) {
      setState(() {
        _formReady = false;
        _pending = null;
        _error = 'calendar_time_account_changed';
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _reload = false;
      _formReady = false;
    });
    try {
      if (await AccountStorage.getUserId() != widget.userId) {
        throw const CalendarCommandError('calendar_time_account_changed');
      }
      final pending = await CalendarHealthApi.pending(widget.userId);
      if (!mounted) return;
      if (await AccountStorage.getUserId() != widget.userId) {
        throw const CalendarCommandError('calendar_time_account_changed');
      }
      _pending = pending;
      _recovering = pending != null;
      if (pending != null) return;
      final data = await CalendarHealthApi.day(widget.userId, widget.date);
      if (data == null) {
        throw const CalendarCommandError('calendar_health_unavailable');
      }
      Map<String, dynamic>? source;
      if (widget.session != null) {
        final matches = (data['sessions'] as List).where(
          (s) => s['source']['id'] == widget.session!['source']['id'],
        );
        if (matches.isEmpty) {
          throw const CalendarCommandError('calendar_health_missing');
        }
        source = Map<String, dynamic>.from(matches.first as Map);
      }
      if (source == null &&
              !(data['capabilities'] as List).contains(
                'create_${widget.kind}',
              ) ||
          source != null &&
              !(source['capabilities'] as List).contains('update')) {
        throw const CalendarCommandError('calendar_health_unavailable');
      }
      if (!mounted) return;
      _source = source;
      _startFold = null;
      _endFold = null;
      _startSecond = 0;
      _endSecond = 0;
      _startDay = DateUtils.dateOnly(widget.date);
      _endDay = _startDay;
      _start = TimeOfDay(hour: widget.hour ?? (_isSleep ? 23 : 12), minute: 0);
      _end = TimeOfDay(
        hour: _isSleep && widget.hour == null ? 7 : ((_start.hour + 1) % 24),
        minute: 0,
      );
      if (_isSleep && widget.hour == null) {
        _startDay = DateTime(_endDay.year, _endDay.month, _endDay.day - 1);
      } else if (_start.hour == 23) {
        _endDay = DateTime(_startDay.year, _startDay.month, _startDay.day + 1);
      }
      if (source == null) {
        try {
          _zone = await CalendarTimeZone.deviceName();
          _zoneConfirmed = true;
          _manualZone = false;
        } catch (_) {
          _zone = 'UTC';
          _zoneConfirmed = false;
          _manualZone = true;
          _error = 'calendar_health_zone_check';
        }
      } else {
        _zoneConfirmed = true;
        _manualZone = false;
        _zone = source['timezone'] as String;
        final start = CalendarTimeZone.inZone(
          DateTime.parse(source['started_at'] as String),
          _zone,
        );
        final end = CalendarTimeZone.inZone(
          DateTime.parse(source['ended_at'] as String),
          _zone,
        );
        _startDay = DateUtils.dateOnly(start);
        _endDay = DateUtils.dateOnly(end);
        _start = TimeOfDay.fromDateTime(start);
        _end = TimeOfDay.fromDateTime(end);
        _startSecond = start.second;
        _endSecond = end.second;
        _activity = source['activity_kind'] as String? ?? 'walk';
        _sleep = source['sleep_kind'] as String? ?? 'main';
        _distance.text = source['distance_km']?.toString() ?? '';
        _startFold = _candidates(
          true,
        ).indexWhere((v) => v.timeZoneOffset == start.timeZoneOffset);
        _endFold = _candidates(
          false,
        ).indexWhere((v) => v.timeZoneOffset == end.timeZoneOffset);
      }
      if (!mounted) return;
      if (await AccountStorage.getUserId() != widget.userId) {
        throw const CalendarCommandError('calendar_time_account_changed');
      }
      _formReady = true;
    } on CalendarCommandError catch (e) {
      if (mounted) _error = e.messageKey;
    } catch (_) {
      if (mounted) _error = 'calendar_health_load_error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DateTime> _candidates(bool start) =>
      CalendarTimeZone.candidates(
            start ? _startDay : _endDay,
            (start ? _start : _end).hour,
            (start ? _start : _end).minute,
            _zone,
          )
          .map(
            (value) =>
                value.add(Duration(seconds: start ? _startSecond : _endSecond)),
          )
          .toList();
  DateTime? _instant(bool start) {
    final values = _candidates(start);
    final fold = start ? _startFold : _endFold;
    if (values.length == 1) return values.single;
    return fold != null && fold >= 0 && fold < values.length
        ? values[fold]
        : null;
  }

  Future<void> _pick(bool start, bool date) async {
    if (date) {
      final value = await showDatePicker(
        context: context,
        initialDate: start ? _startDay : _endDay,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (!mounted || value == null) return;
      setState(() {
        if (start) {
          _startDay = value;
          _startFold = null;
        } else {
          _endDay = value;
          _endFold = null;
        }
      });
    } else {
      final value = await showTimePicker(
        context: context,
        initialTime: start ? _start : _end,
      );
      if (!mounted || value == null) return;
      setState(() {
        if (start) {
          _start = value;
          _startSecond = 0;
          _startFold = null;
        } else {
          _end = value;
          _endSecond = 0;
          _endFold = null;
        }
      });
    }
  }

  Map<String, dynamic>? _input() {
    if (!_zoneConfirmed) return null;
    final start = _instant(true), end = _instant(false);
    if (start == null || end == null) return null;
    final seconds = end.difference(start).inSeconds;
    if (seconds < 60 || seconds > 86400 || end.isAfter(DateTime.now())) {
      return null;
    }
    var distance = _distance.text.trim().replaceAll('٫', '.');
    for (var digit = 0; digit < 10; digit++) {
      distance = distance
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[digit], '$digit')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[digit], '$digit');
    }
    if (!_isSleep &&
        distance.isNotEmpty &&
        (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(distance) ||
            double.tryParse(distance) == null ||
            double.parse(distance) <= 0 ||
            double.parse(distance) > 1000)) {
      return null;
    }
    return {
      'kind': widget.kind,
      'entry_date': calendarDate(_isSleep ? end : start),
      'started_at': CalendarTimeZone.timestamp(
        start,
        precise: true,
      ).replaceFirst('.000000', ''),
      'ended_at': CalendarTimeZone.timestamp(
        end,
        precise: true,
      ).replaceFirst('.000000', ''),
      'timezone': _zone,
      if (_isSleep) 'sleep_kind': _sleep,
      if (!_isSleep) 'activity_kind': _activity,
      if (!_isSleep && distance.isNotEmpty) 'distance_km': distance,
    };
  }

  Future<void> _save({bool delete = false}) async {
    if (_saving) return;
    if (delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('calendar_health_delete')),
          content: Text(t('calendar_health_delete_confirm')),
          actions: [
            TextButton(
              style: calendarActionStyle(context),
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('cancel')),
            ),
            TextButton(
              style: calendarActionStyle(context),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('calendar_health_delete')),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    final input = _pending != null || delete ? null : _input();
    if (_pending == null && !delete && input == null) {
      setState(() => _error = 'calendar_health_invalid');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_pending != null) {
        await CalendarHealthApi.retry(widget.userId);
      } else {
        await CalendarHealthApi.submit(widget.userId, {
          'action': delete
              ? 'delete'
              : _source == null
              ? 'create'
              : 'update',
          if (_source != null) 'source': _source!['source'],
          if (!delete) 'session': input,
        }, preview: delete ? _source : input);
      }
      if (!mounted) return;
      if (await AccountStorage.getUserId() != widget.userId) {
        throw const CalendarCommandError('calendar_time_account_changed');
      }
      if (mounted) Navigator.pop(context, true);
    } on CalendarCommandError catch (e) {
      if (mounted) {
        _error = e.messageKey;
        _reload = e.reload;
      }
    } catch (_) {
      if (mounted) _error = 'calendar_time_uncertain';
    } finally {
      try {
        _pending = await CalendarHealthApi.pending(widget.userId);
        if (_pending != null) _recovering = true;
        if (await AccountStorage.getUserId() != widget.userId) {
          _pending = null;
          _formReady = false;
        }
      } catch (_) {
        /* Keep local recovery state. */
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeFields(bool start) {
    final values = _candidates(start), fold = start ? _startFold : _endFold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t(
            _isSleep
                ? (start
                      ? 'calendar_health_sleep_start'
                      : 'calendar_health_sleep_end')
                : (start ? 'calendar_health_start' : 'calendar_health_end'),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              style: calendarActionStyle(context),
              onPressed: () => _pick(start, true),
              child: Text(
                DateFormat.yMMMd(
                  AppLocalizations.of(context).locale.languageCode,
                ).format(start ? _startDay : _endDay),
              ),
            ),
            OutlinedButton(
              style: calendarActionStyle(context),
              onPressed: () => _pick(start, false),
              child: Text((start ? _start : _end).format(context)),
            ),
          ],
        ),
        if (values.isEmpty)
          Text(
            t('calendar_health_gap'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (values.length > 1)
          DropdownButtonFormField<int>(
            key: ValueKey(
              '${start}_${calendarDate(start ? _startDay : _endDay)}_${start ? _start : _end}_$_zone',
            ),
            initialValue: fold != null && fold >= 0 && fold < values.length
                ? fold
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: t('calendar_health_offset')),
            items: [
              for (var i = 0; i < values.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('UTC${CalendarTimeZone.offset(values[i])}'),
                ),
            ],
            onChanged: (v) => setState(() {
              if (start) {
                _startFold = v;
              } else {
                _endFold = v;
              }
            }),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _formReady;
    final input = ready && _pending == null ? _input() : null;
    final review = (_pending?['session'] ?? _pending?['_preview']) as Map?;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  t(
                    _pending != null
                        ? 'calendar_health_retry'
                        : _isSleep
                        ? 'calendar_health_sleep'
                        : 'calendar_health_activity',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      t(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_pending != null) ...[
                  Text(t('calendar_health_pending')),
                  Text(t('calendar_health_${_pending!['action']}')),
                  if (_pending!['source'] != null)
                    Text('#${_pending!['source']['id']}'),
                  if (review != null) ...[
                    Text(t('calendar_health_${review['kind']}')),
                    Text(
                      t(
                        'calendar_health_${review['activity_kind'] ?? review['sleep_kind']}',
                      ),
                    ),
                    Text('${review['started_at']} → ${review['ended_at']}'),
                    Text('${review['timezone']}'),
                    if (review['distance_km'] != null)
                      Text(
                        '${review['distance_km']} ${t('calendar_health_km')}',
                      ),
                  ],
                ] else if (ready && !_reload) ...[
                  Text(
                    t(
                      _isSleep
                          ? 'calendar_health_sleep_help'
                          : 'calendar_health_activity_help',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _isSleep ? _sleep : _activity,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('calendar_health_kind'),
                    ),
                    items: [
                      for (final k
                          in _isSleep
                              ? ['main', 'nap']
                              : [
                                  'walk',
                                  'run',
                                  'cycle',
                                  'swim',
                                  'hike',
                                  'yoga',
                                  'weightlifting',
                                  'other',
                                ])
                        DropdownMenuItem(
                          value: k,
                          child: Text(t('calendar_health_$k')),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                            if (_isSleep) {
                              _sleep = v!;
                            } else {
                              _activity = v!;
                            }
                          }),
                  ),
                  const SizedBox(height: 12),
                  if (_manualZone)
                    DropdownButtonFormField<String>(
                      initialValue: _zone,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t('calendar_health_zone'),
                      ),
                      items: [
                        for (final z in CalendarTimeZone.names)
                          DropdownMenuItem(
                            value: z,
                            child: Text(z, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              _zone = v!;
                              _zoneConfirmed = true;
                              if (_error == 'calendar_health_zone_check') {
                                _error = null;
                              }
                              _startFold = null;
                              _endFold = null;
                            }),
                    ),
                  const SizedBox(height: 16),
                  if (_source != null)
                    Text(
                      t(
                        'calendar_health_saved_zone',
                      ).replaceAll('{zone}', _zone),
                    ),
                  IgnorePointer(
                    ignoring: _saving,
                    child: Column(
                      children: [_timeFields(true), _timeFields(false)],
                    ),
                  ),
                  if (!_isSleep)
                    TextField(
                      controller: _distance,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: t('calendar_health_distance'),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  const SizedBox(height: 12),
                  if (input != null)
                    Text(
                      '${t('calendar_health_duration')}: ${_instant(false)!.difference(_instant(true)!).inMinutes} ${t('calendar_health_minutes')}\n${t('calendar_health_date')}: ${input['entry_date']}',
                    ),
                  if (input == null) Text(t('calendar_health_invalid')),
                ],
                const SizedBox(height: 16),
                if (_recovering && _reload) Text(t('calendar_health_reselect')),
                if (!_recovering &&
                    (_reload || (!ready && !_loading && _pending == null)))
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: _saving ? null : _load,
                    child: Text(t('calendar_health_reload')),
                  ),
                if (_pending != null || (ready && !_reload))
                  FilledButton(
                    onPressed: _saving ? null : () => _save(),
                    child: Text(
                      t(
                        _pending != null
                            ? 'calendar_health_retry'
                            : 'calendar_health_save',
                      ),
                    ),
                  ),
                if (_source != null &&
                    (_source!['capabilities'] as List).contains('delete') &&
                    _pending == null &&
                    !_reload)
                  TextButton(
                    style: calendarActionStyle(context),
                    onPressed: _saving ? null : () => _save(delete: true),
                    child: Text(t('calendar_health_delete')),
                  ),
                if (_saving) const Center(child: CircularProgressIndicator()),
                TextButton(
                  style: calendarActionStyle(context),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(t('calendar_health_close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
