import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/account_storage.dart';
import '../services/coach/coach_habits_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

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
  final TextEditingController _habitController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int? _expertId;
  List<CoachHabitItem> _habits = const [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _habitController.dispose();
    super.dispose();
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

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not checked this week';
    return 'Checked ${DateFormat('dd MMM, HH:mm').format(dt.toLocal())}';
  }

  bool _canManageHabits() {
    return _expertId != null && _errorText != 'Non available';
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
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
                  'Checked this week: $checkedCount / $totalCount',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
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
                              _formatDateTime(habit.completedAt),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
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
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Client Habits'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
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
