import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/account_storage.dart';
import '../services/coach/coach_habits_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_toast.dart';

class ExpertClientHabitsPage extends StatefulWidget {
  const ExpertClientHabitsPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.avatarUrl,
  });

  final int clientId;
  final String clientName;
  final String? avatarUrl;

  @override
  State<ExpertClientHabitsPage> createState() => _ExpertClientHabitsPageState();
}

class _ExpertClientHabitsPageState extends State<ExpertClientHabitsPage> {
  static const Duration _reminderCooldownDuration = Duration(minutes: 5);
  static final Map<int, DateTime> _reminderCooldownUntilByClientId =
      <int, DateTime>{};

  final TextEditingController _habitController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _sendingReminder = false;
  String _newHabitType = CoachHabitItem.weeklyType;
  int? _expertId;
  List<CoachHabitItem> _habits = const [];
  String? _errorText;
  Timer? _reminderCooldownTimer;

  @override
  void initState() {
    super.initState();
    _syncReminderCooldownTimer();
    _load();
  }

  @override
  void dispose() {
    _reminderCooldownTimer?.cancel();
    _habitController.dispose();
    super.dispose();
  }

  DateTime? _reminderCooldownUntil() {
    final until = _reminderCooldownUntilByClientId[widget.clientId];
    if (until == null) return null;
    if (!until.isAfter(DateTime.now())) {
      _reminderCooldownUntilByClientId.remove(widget.clientId);
      return null;
    }
    return until;
  }

  bool _isReminderCooldownActive() {
    return _reminderCooldownUntil() != null;
  }

  void _activateReminderCooldown() {
    _reminderCooldownUntilByClientId[widget.clientId] = DateTime.now().add(
      _reminderCooldownDuration,
    );
    _syncReminderCooldownTimer();
  }

  void _syncReminderCooldownTimer() {
    _reminderCooldownTimer?.cancel();
    final until = _reminderCooldownUntil();
    if (until == null) return;
    final wait = until.difference(DateTime.now());
    final delay = wait.isNegative ? Duration.zero : wait;
    _reminderCooldownTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _syncReminderCooldownTimer();
    });
  }

  Future<void> _load({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }

    final expertId = await AccountStorage.getUserId();
    if (expertId == null || expertId <= 0) {
      if (!mounted) return;
      setState(() {
        _expertId = null;
        _habits = const [];
        _errorText = 'Non available';
        _loading = false;
      });
      return;
    }

    try {
      final habits = await CoachHabitsService.fetchClientHabits(
        clientId: widget.clientId,
        expertId: expertId,
        includeCompleted: true,
      );
      if (!mounted) return;
      setState(() {
        _expertId = expertId;
        _habits = habits;
        _errorText = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _expertId = expertId;
        _habits = const [];
        _errorText = _normalizeError(e);
        _loading = false;
      });
    }
  }

  String _normalizeError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('forbidden') || lower.contains('403')) {
      return 'Non available';
    }
    if (raw.startsWith('Exception: ')) {
      final clean = raw.substring('Exception: '.length).trim();
      if (clean.isNotEmpty) return clean;
    }
    return raw.isEmpty ? 'Non available' : raw;
  }

  String _initials() {
    final trimmed = widget.clientName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatDateTime(CoachHabitItem habit) {
    final dt = habit.completedAt;
    if (dt == null) {
      return habit.isDaily ? 'Not checked today' : 'Not checked this week';
    }
    return 'Checked ${DateFormat('dd MMM, HH:mm').format(dt.toLocal())}';
  }

  String _habitTypeLabel(String type) {
    return type == CoachHabitItem.dailyType ? 'Daily' : 'Weekly';
  }

  bool _canManageHabits() {
    return _expertId != null && _errorText != 'Non available';
  }

  int _uncheckedHabitsCount() {
    return _habits.where((h) => !h.isCompleted).length;
  }

  Future<void> _sendReminder() async {
    if (_sendingReminder || _saving || !_canManageHabits()) return;
    if (_isReminderCooldownActive()) {
      AppToast.show(
        context,
        'Reminder cooldown is active.',
        type: AppToastType.info,
      );
      return;
    }

    final total = _habits.length;
    final unchecked = _uncheckedHabitsCount();
    if (total == 0) {
      AppToast.show(
        context,
        'No habits assigned. Reminder not sent.',
        type: AppToastType.info,
      );
      return;
    }
    if (unchecked == 0) {
      AppToast.show(
        context,
        'All habits are checked. Reminder not sent.',
        type: AppToastType.info,
      );
      return;
    }

    setState(() => _sendingReminder = true);
    try {
      final result = await CoachHabitsService.sendClientHabitsReminder(
        clientId: widget.clientId,
      );
      if (!mounted) return;
      final triggered = result['triggered'] == true;
      final reason = (result['reason'] ?? '').toString();
      if (triggered) {
        _activateReminderCooldown();
        setState(() {});
        AppToast.show(context, 'Reminder sent.', type: AppToastType.success);
      } else if (reason == 'no_habits_assigned') {
        AppToast.show(
          context,
          'No habits assigned. Reminder not sent.',
          type: AppToastType.info,
        );
      } else if (reason == 'no_unchecked_habits') {
        AppToast.show(
          context,
          'All habits are checked. Reminder not sent.',
          type: AppToastType.info,
        );
      } else if (reason == 'no_active_push_tokens') {
        AppToast.show(
          context,
          'Client has no active push token.',
          type: AppToastType.info,
        );
      } else {
        AppToast.show(context, 'Reminder not sent.', type: AppToastType.info);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, _normalizeError(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  Future<void> _addHabit() async {
    if (_saving || _expertId == null) return;
    final habit = _habitController.text.trim();
    if (habit.isEmpty) {
      AppToast.show(context, 'Enter a habit.', type: AppToastType.info);
      return;
    }

    setState(() => _saving = true);
    try {
      await CoachHabitsService.addClientHabit(
        clientId: widget.clientId,
        habit: habit,
        habitType: _newHabitType,
      );
      _habitController.clear();
      await _load(showLoading: false);
      if (!mounted) return;
      AppToast.show(context, 'Habit added.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, _normalizeError(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteHabit(CoachHabitItem habit) async {
    if (_saving || _expertId == null) return;
    setState(() => _saving = true);
    try {
      await CoachHabitsService.deleteClientHabit(habitId: habit.id);
      await _load(showLoading: false);
      if (!mounted) return;
      AppToast.show(context, 'Habit removed.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, _normalizeError(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildHeaderCard() {
    final imageUrl = (widget.avatarUrl ?? '').trim();
    final checkedCount = _habits.where((h) => h.isCompleted).length;
    final totalCount = _habits.length;
    final canManage = _canManageHabits();
    final isCooldownActive = _isReminderCooldownActive();
    final canSendReminder =
        canManage &&
        totalCount > 0 &&
        _uncheckedHabitsCount() > 0 &&
        !isCooldownActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white10,
                foregroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                onForegroundImageError: (_, _) {},
                child: Text(
                  _initials(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Checked in current cycle: $checkedCount / $totalCount',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sendingReminder || !canSendReminder
                  ? null
                  : _sendReminder,
              icon: _sendingReminder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isCooldownActive
                          ? Icons.hourglass_top_rounded
                          : Icons.notifications_active_outlined,
                    ),
              label: Text(
                _sendingReminder
                    ? 'Sending...'
                    : isCooldownActive
                    ? 'Reminder Cooldown Active'
                    : 'Remind Client to Check Habits',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white54,
              ),
            ),
          ),
          if (!canSendReminder && canManage)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                isCooldownActive
                    ? 'Reminder cooldown is active for this client.'
                    : 'Reminder is available only when at least one assigned habit is unchecked.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    final canManage = _canManageHabits();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Habits',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _habitController,
            enabled: canManage,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addHabit(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Example: 20 min walk daily',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.8),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Weekly'),
                selected: _newHabitType == CoachHabitItem.weeklyType,
                onSelected: !canManage
                    ? null
                    : (_) {
                        setState(
                          () => _newHabitType = CoachHabitItem.weeklyType,
                        );
                      },
              ),
              ChoiceChip(
                label: const Text('Daily'),
                selected: _newHabitType == CoachHabitItem.dailyType,
                onSelected: !canManage
                    ? null
                    : (_) {
                        setState(
                          () => _newHabitType = CoachHabitItem.dailyType,
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || !canManage ? null : _addHabit,
              child: Text(_saving ? 'Saving...' : 'Add Habit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsListCard() {
    final habits = List<CoachHabitItem>.from(_habits)
      ..sort((a, b) {
        final completedSort = (a.isCompleted ? 1 : 0).compareTo(
          b.isCompleted ? 1 : 0,
        );
        if (completedSort != 0) return completedSort;
        final ad = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Habits',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.white70))
          else if (habits.isEmpty)
            const Text(
              'No habits set yet.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...habits.map(
              (habit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        habit.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: habit.isCompleted
                            ? AppColors.successGreen
                            : Colors.white38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.habit,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Type: ${_habitTypeLabel(habit.habitType)}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(habit),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            if (habit.isDaily &&
                                habit.weekStart != null &&
                                habit.today != null) ...[
                              const SizedBox(height: 6),
                              _WeekChecklistRow(habit: habit),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _saving || !_canManageHabits()
                            ? null
                            : () => _deleteHabit(habit),
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 12),
          _buildAddCard(),
          const SizedBox(height: 12),
          _buildHabitsListCard(),
          const SizedBox(height: 20),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.black,
        titleColor: Colors.white,
        title: 'Client Habits',
        trailing: IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ),
      body: Stack(
        children: [
          body,
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mon-Sun row showing which days this week a daily habit was checked, up
/// through [CoachHabitItem.today]. Days after today haven't happened yet, so
/// they render as an empty placeholder instead of "unchecked".
class _WeekChecklistRow extends StatelessWidget {
  const _WeekChecklistRow({required this.habit});

  final CoachHabitItem habit;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final weekStart = habit.weekStart!;
    final today = habit.today!;
    return Row(
      children: List.generate(7, (index) {
        final day = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + index,
        );
        final isFuture = day.isAfter(today);
        final isChecked = habit.completedDatesThisWeek.any(
          (d) => _sameDay(d, day),
        );

        Color background;
        Color foreground;
        if (isFuture) {
          background = Colors.transparent;
          foreground = Colors.white24;
        } else if (isChecked) {
          background = AppColors.successGreen.withValues(alpha: 0.18);
          foreground = AppColors.successGreen;
        } else {
          background = Colors.white.withValues(alpha: 0.05);
          foreground = Colors.white38;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFuture ? Colors.white12 : foreground,
                    width: 1,
                  ),
                ),
                child: isChecked
                    ? Icon(Icons.check, size: 11, color: foreground)
                    : null,
              ),
              const SizedBox(height: 2),
              Text(
                _dayLabels[index],
                style: TextStyle(fontSize: 9, color: foreground),
              ),
            ],
          ),
        );
      }),
    );
  }
}
