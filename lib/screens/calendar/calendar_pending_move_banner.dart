import 'package:flutter/material.dart';
import 'calendar_action_style.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/calendar/calendar_food_commands.dart';
import 'calendar_time_editor_sheet.dart';

/// Retry remains reachable even if a successful-but-unacknowledged move removed
/// the card from the current day, or the timeline itself failed to load.
class CalendarPendingMoveBanner extends StatefulWidget {
  const CalendarPendingMoveBanner({super.key, required this.onSaved});
  final Future<void> Function() onSaved;
  @override
  State<CalendarPendingMoveBanner> createState() =>
      _CalendarPendingMoveBannerState();
}

class _CalendarPendingMoveBannerState extends State<CalendarPendingMoveBanner> {
  PendingCalendarMove? _pending;
  int? _userId;
  bool _opening = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    CalendarFoodCommands.changes.addListener(_load);
    AccountStorage.accountChange.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    CalendarFoodCommands.changes.removeListener(_load);
    AccountStorage.accountChange.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final userId = await AccountStorage.getUserId();
      final pending = userId == null
          ? null
          : await CalendarFoodCommands.pending(userId);
      final activeUser = await AccountStorage.getUserId();
      if (!mounted || generation != _generation || activeUser != userId) {
        return;
      }
      setState(() {
        _pending = pending;
        _userId = userId;
      });
    } catch (_) {
      /* Receipt stays stored if local storage is temporarily unavailable. */
    }
  }

  Future<void> _open() async {
    final pending = _pending;
    if (_opening || pending == null || _userId == null) return;
    setState(() => _opening = true);
    try {
      final saved = await showCalendarTimeEditor(
        context,
        userId: _userId!,
        kind: pending.kind,
        foodId: pending.id,
        copy: pending.isCopy,
      );
      if (saved) {
        try {
          await widget.onSaved();
        } catch (_) {
          debugPrint('Calendar saved; timeline refresh failed.');
        }
      }
      await _load();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.translate('calendar_time_pending_move')),
          TextButton(
            style: calendarActionStyle(context),
            onPressed: _opening ? null : _open,
            child: Text(
              t.translate(
                _pending!.isDetails
                    ? 'calendar_details_retry'
                    : _pending!.isBulk
                    ? 'calendar_bulk_retry'
                    : _pending!.isCopy
                    ? 'calendar_copy_retry'
                    : 'calendar_time_retry',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
