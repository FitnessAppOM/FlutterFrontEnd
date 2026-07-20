import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/account_storage.dart';
import '../services/coach/coach_habits_service.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_empty_state_row.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_pill_tab.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class ExpertClientHabitsPage extends StatefulWidget {
  const ExpertClientHabitsPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.avatarUrl,
    this.clientActivityStatus,
  });

  final int clientId;
  final String clientName;
  final String? avatarUrl;
  final String? clientActivityStatus;

  @override
  State<ExpertClientHabitsPage> createState() => _ExpertClientHabitsPageState();
}

class _ExpertClientHabitsPageState extends State<ExpertClientHabitsPage> {
  static const Duration _reminderCooldownDuration = Duration(minutes: 5);
  static final Map<int, DateTime> _reminderCooldownUntilByClientId =
      <int, DateTime>{};
  static final Map<int, List<CoachHabitItem>> _habitsCache =
      <int, List<CoachHabitItem>>{};

  final TextEditingController _habitController = TextEditingController();

  bool _loading = true;
  bool _hasCompletedInitialLoad = false;
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
    final cached = _habitsCache[widget.clientId];
    if (cached != null) {
      _habits = cached;
      _loading = false;
      _hasCompletedInitialLoad = true;
      _load(showLoading: false);
    } else {
      _load();
    }
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
        _hasCompletedInitialLoad = true;
      });
      return;
    }

    try {
      final habits = await CoachHabitsService.fetchClientHabits(
        clientId: widget.clientId,
        expertId: expertId,
        includeCompleted: true,
      );
      _habitsCache[widget.clientId] = habits;
      if (!mounted) return;
      setState(() {
        _expertId = expertId;
        _habits = habits;
        _errorText = null;
        _loading = false;
        _hasCompletedInitialLoad = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _expertId = expertId;
        _habits = const [];
        _errorText = _normalizeError(e);
        _loading = false;
        _hasCompletedInitialLoad = true;
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
    final checkedCount = _habits.where((h) => h.isCompleted).length;
    final totalCount = _habits.length;
    final canManage = _canManageHabits();
    final isCooldownActive = _isReminderCooldownActive();
    final canSendReminder =
        canManage &&
        totalCount > 0 &&
        _uncheckedHabitsCount() > 0 &&
        !isCooldownActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaExpertClientCard(
          name: widget.clientName,
          avatarUrl: widget.avatarUrl,
          status: widget.clientActivityStatus,
          showStatus: (widget.clientActivityStatus ?? '').trim().isNotEmpty,
          subtitle: 'User ID: ${widget.clientId}',
          details: ['Checked in current cycle: $checkedCount / $totalCount'],
          alerts: const [],
        ),
        SizedBox(height: TaqaUiScale.h(12)),
        TaqaFilledButton(
          label: _sendingReminder
              ? 'Sending...'
              : 'Remind Client to Check Habits',
          onTap: _sendingReminder || !canSendReminder ? null : _sendReminder,
          loading: _sendingReminder,
          height: 45,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        if (!canSendReminder)
          Padding(
            padding: EdgeInsets.only(top: TaqaUiScale.h(7)),
            child: Text(
              'Reminder is available only when at least one assigned habit is unchecked.',
              style: TextStyle(
                color: TaqaUiColors.charcoal,
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(10),
                fontWeight: FontWeight.w400,
                height: 12 / 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddCard() {
    final canManage = _canManageHabits();
    return TaqaManagementListCard(
      minHeight: 206,
      radius: 15,
      showBorder: false,
      padding: TaqaUiScale.insetsLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habit',
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(15),
              height: 25 / 15,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(6)),
          TextField(
            controller: _habitController,
            enabled: canManage,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addHabit(),
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
            ),
            decoration: InputDecoration(
              hintText: 'Example: 20 min walk daily',
              hintStyle: TextStyle(
                color: TaqaUiColors.unnamedColorE3e3e3,
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w400,
                height: 21 / 15,
              ),
              isDense: true,
              contentPadding: EdgeInsets.only(bottom: TaqaUiScale.h(6)),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: TaqaUiColors.charcoal, width: .5),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: TaqaUiColors.charcoal, width: .5),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: TaqaUiColors.charcoal, width: .5),
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          Row(
            children: [
              Expanded(
                child: TaqaPillTab(
                  label: 'Weekly',
                  active: _newHabitType == CoachHabitItem.weeklyType,
                  activeColor: TaqaUiColors.charcoal,
                  activeTextColor: TaqaUiColors.white,
                  onTap: !canManage
                      ? null
                      : () => setState(
                          () => _newHabitType = CoachHabitItem.weeklyType,
                        ),
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: TaqaPillTab(
                  label: 'Daily',
                  active: _newHabitType == CoachHabitItem.dailyType,
                  activeColor: TaqaUiColors.charcoal,
                  activeTextColor: TaqaUiColors.white,
                  onTap: !canManage
                      ? null
                      : () => setState(
                          () => _newHabitType = CoachHabitItem.dailyType,
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          TaqaFilledButton(
            label: _saving ? 'Saving...' : 'Add Habit',
            onTap: _saving || !canManage ? null : _addHabit,
            loading: _saving,
            height: 45,
            fontSize: 10,
            fontWeight: FontWeight.w600,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habits',
          style: TextStyle(
            color: TaqaUiColors.charcoal,
            fontFamily: TaqaUiFontFamilies.interTight,
            fontWeight: FontWeight.w700,
            fontSize: TaqaUiScale.sp(15),
            height: 25 / 15,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(8)),
        if (_errorText != null)
          const TaqaEmptyStateRow(text: 'Habits are not available.')
        else if (habits.isEmpty)
          const TaqaEmptyStateRow(text: 'No habits set yet.')
        else
          ...habits.map(
            (habit) => Padding(
              padding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
              child: TaqaManagementListCard(
                radius: 15,
                showBorder: false,
                padding: TaqaUiScale.insetsLTRB(14, 10, 6, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.habit,
                            style: TextStyle(
                              color: TaqaUiColors.charcoal,
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(15),
                              fontWeight: FontWeight.w700,
                              height: 25 / 15,
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(2)),
                          Text(
                            'Type: ${_habitTypeLabel(habit.habitType)}',
                            style: TextStyle(
                              color: TaqaUiColors.charcoal,
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(15),
                              fontWeight: FontWeight.w400,
                              height: 25 / 15,
                            ),
                          ),
                          if (habit.isDaily &&
                              habit.weekStart != null &&
                              habit.today != null) ...[
                            SizedBox(height: TaqaUiScale.h(5)),
                            _WeekChecklistRow(habit: habit),
                            SizedBox(height: TaqaUiScale.h(7)),
                          ],
                          TaqaClientAlertText(text: _formatDateTime(habit)),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Delete',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saving || !_canManageHabits()
                              ? null
                              : () => _deleteHabit(habit),
                          borderRadius: TaqaUiScale.radius(5),
                          child: SizedBox(
                            width: TaqaUiScale.w(20),
                            height: TaqaUiScale.h(20),
                            child: Center(
                              child: Icon(
                                Icons.close,
                                color: TaqaUiColors.charcoal,
                                size: TaqaUiScale.w(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showInitialLoading = _loading && !_hasCompletedInitialLoad;
    final body = showInitialLoading
        ? const Center(child: TaqaLoadingIndicator())
        : TaqaRefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TaqaUiScale.insetsLTRB(16, 12, 17, 24),
              children: [
                _buildHeaderCard(),
                SizedBox(height: TaqaUiScale.h(12)),
                _buildAddCard(),
                SizedBox(height: TaqaUiScale.h(12)),
                _buildHabitsListCard(),
                SizedBox(height: TaqaUiScale.h(20)),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.unnamedColor1c1d17,
        title: 'Habits',
      ),
      body: body,
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
          foreground = TaqaUiColors.charcoal.withValues(alpha: 0.24);
        } else if (isChecked) {
          background = const Color(0xFF3BE971).withValues(alpha: 0.18);
          foreground = const Color(0xFF3BE971);
        } else {
          background = TaqaUiColors.charcoal.withValues(alpha: 0.05);
          foreground = TaqaUiColors.charcoal.withValues(alpha: 0.38);
        }

        return Padding(
          padding: EdgeInsets.only(right: TaqaUiScale.w(5)),
          child: Column(
            children: [
              Container(
                width: TaqaUiScale.w(18),
                height: TaqaUiScale.h(18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFuture ? Colors.white12 : foreground,
                    width: TaqaUiScale.r(1),
                  ),
                ),
                child: isChecked
                    ? Icon(
                        Icons.check,
                        size: TaqaUiScale.w(11),
                        color: foreground,
                      )
                    : null,
              ),
              SizedBox(height: TaqaUiScale.h(2)),
              Text(
                _dayLabels[index],
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(9),
                  color: foreground,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
