import 'package:flutter/material.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_health_api.dart';
import 'calendar_health_sheet.dart';
import 'calendar_action_style.dart';

/// Recovery remains available when the source day/card or optional API is absent.
class CalendarHealthBanner extends StatefulWidget {
  const CalendarHealthBanner({super.key, required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<CalendarHealthBanner> createState() => _CalendarHealthBannerState();
}

class _CalendarHealthBannerState extends State<CalendarHealthBanner> {
  int? _user;
  bool _pending = false, _opening = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    CalendarHealthApi.changes.addListener(_load);
    AccountStorage.accountChange.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    CalendarHealthApi.changes.removeListener(_load);
    AccountStorage.accountChange.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final user = await AccountStorage.getUserId();
    try {
      final pending = user == null
          ? null
          : await CalendarHealthApi.pending(user);
      if (mounted &&
          generation == _generation &&
          user == await AccountStorage.getUserId()) {
        setState(() {
          _user = user;
          _pending = pending != null;
        });
      }
    } catch (_) {
      /* Persisted receipt remains available on the next refresh. */
    }
  }

  Future<void> _open() async {
    final user = _user;
    if (_opening || user == null) return;
    setState(() => _opening = true);
    try {
      final saved = await showCalendarHealth(
        context,
        userId: user,
        date: DateTime.now(),
      );
      if (saved == true && mounted) await widget.onSaved();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => !_pending
      ? const SizedBox.shrink()
      : TextButton.icon(
          style: calendarActionStyle(context),
          onPressed: _opening ? null : _open,
          icon: const Icon(Icons.sync_problem),
          label: Text(
            AppLocalizations.of(context).translate('calendar_health_retry'),
          ),
        );
}
