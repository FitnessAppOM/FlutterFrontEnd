import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/coach_habits_service.dart';
import '../../services/coach/form_check_service.dart';
import '../../theme/app_theme.dart';

class CoachFeedbackPanel extends StatefulWidget {
  const CoachFeedbackPanel({super.key});

  @override
  State<CoachFeedbackPanel> createState() => _CoachFeedbackPanelState();
}

class _CoachFeedbackPanelState extends State<CoachFeedbackPanel> {
  bool _loadingHabits = true;
  String? _habitsError;
  List<CoachHabitItem> _habits = const [];
  final Set<int> _updatingHabitIds = <int>{};
  bool _loadingFeedback = true;
  String? _feedbackError;
  List<FormCheckSubmission> _feedbackItems = const [];
  List<FormCheckSubmission> _pinnedFeedbackItems = const [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
    _loadFeedbackFeed();
  }

  Future<void> _loadHabits() async {
    setState(() {
      _loadingHabits = true;
      _habitsError = null;
      _updatingHabitIds.clear();
    });

    final userId = await AccountStorage.getUserId();
    if (userId == null || userId <= 0) {
      if (!mounted) return;
      setState(() {
        _loadingHabits = false;
        _habits = const [];
        _habitsError = 'missing_user';
        _updatingHabitIds.clear();
      });
      return;
    }

    try {
      final habits = await CoachHabitsService.fetchClientHabits(
        clientId: userId,
        includeCompleted: true,
      );
      if (!mounted) return;
      setState(() {
        _loadingHabits = false;
        _habits = habits;
        _habitsError = null;
        _updatingHabitIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHabits = false;
        _habits = const [];
        _habitsError = e.toString();
        _updatingHabitIds.clear();
      });
    }
  }

  Future<void> _toggleHabit(CoachHabitItem habit) async {
    if (_updatingHabitIds.contains(habit.id)) return;

    final nextCompleted = !habit.isCompleted;
    final previous = habit;

    setState(() {
      _updatingHabitIds.add(habit.id);
      _habits = _habits
          .map(
            (h) => h.id == habit.id
                ? h.copyWith(
                    isCompleted: nextCompleted,
                    completedAt: nextCompleted ? DateTime.now() : null,
                    clearCompletedAt: !nextCompleted,
                  )
                : h,
          )
          .toList();
    });

    try {
      final updated = await CoachHabitsService.setHabitCompletion(
        habitId: habit.id,
        isCompleted: nextCompleted,
      );
      if (!mounted) return;
      setState(() {
        _habits = _habits.map((h) => h.id == updated.id ? updated : h).toList();
      });
    } catch (_) {
      if (!mounted) return;
      final t = AppLocalizations.of(context);
      setState(() {
        _habits = _habits
            .map((h) => h.id == previous.id ? previous : h)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('coach_habits_load_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingHabitIds.remove(habit.id);
        });
      }
    }
  }

  Future<void> _loadFeedbackFeed() async {
    setState(() {
      _loadingFeedback = true;
      _feedbackError = null;
    });
    try {
      final feed = await FormCheckService.fetchFeedbackFeed();
      if (!mounted) return;
      setState(() {
        _feedbackItems = feed.items;
        _pinnedFeedbackItems = feed.pinnedItems;
        _loadingFeedback = false;
        _feedbackError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackItems = const [];
        _pinnedFeedbackItems = const [];
        _loadingFeedback = false;
        _feedbackError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatFeedDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(target).inDays;
    if (diffDays == 0) {
      return 'Today, ${DateFormat('HH:mm').format(local)}';
    }
    if (diffDays == 1) {
      return 'Yesterday, ${DateFormat('HH:mm').format(local)}';
    }
    return DateFormat('MMM d, HH:mm').format(local);
  }

  String _feedbackMessage(FormCheckSubmission item) {
    if (item.coachReviewReplies.isNotEmpty) {
      final text = item.coachReviewReplies.last.replyText.trim();
      if (text.isNotEmpty) return text;
    }
    return (item.coachReview?.reviewText ?? '').trim();
  }

  FormCheckCoachReply? _latestPinnedReply(FormCheckSubmission item) {
    for (final reply in item.coachReviewReplies.reversed) {
      if (reply.isPinned) return reply;
    }
    return null;
  }

  String _pinnedFeedbackMessage(FormCheckSubmission item) {
    final pinnedReply = _latestPinnedReply(item);
    if (pinnedReply != null) {
      final text = pinnedReply.replyText.trim();
      if (text.isNotEmpty) return text;
    }
    if (item.coachReview?.isPinned == true) {
      return (item.coachReview?.reviewText ?? '').trim();
    }
    return '';
  }

  bool _isPinned(FormCheckSubmission item) {
    if (item.coachReview?.isPinned == true) return true;
    return _latestPinnedReply(item) != null;
  }

  DateTime? _feedbackTime(FormCheckSubmission item) {
    if (item.coachReviewReplies.isNotEmpty) {
      final last = item.coachReviewReplies.last;
      return last.createdAt ?? last.updatedAt;
    }
    return item.coachReview?.reviewedAt ??
        item.updatedAt ??
        item.sharedAt ??
        item.createdAt;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pinnedCorrections = _pinnedFeedbackItems
        .where((item) => _pinnedFeedbackMessage(item).isNotEmpty)
        .map(
          (item) => _PinnedCorrection(
            title: _pinnedFeedbackMessage(item),
            exercise: item.exerciseName,
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _CoachTasksCard(
          title: t.translate('coach_tasks_title'),
          subtitle: t.translate('coach_tasks_subtitle'),
          dailyHabitsTitle: t.translate('coach_tasks_daily_habits'),
          pinnedCorrectionsTitle: t.translate('coach_tasks_pinned_corrections'),
          habits: _habits,
          loadingHabits: _loadingHabits,
          habitsError: _habitsError,
          emptyHabitsLabel: t.translate('coach_habits_empty'),
          loadFailedLabel: t.translate('coach_habits_load_failed'),
          onHabitToggle: _toggleHabit,
          updatingHabitIds: _updatingHabitIds,
          corrections: pinnedCorrections,
          emptyPinnedLabel: 'No pinned replies yet.',
        ),
        const SizedBox(height: 16),
        Text(
          t.translate('coach_feedback_feed_title'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingFeedback)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (!_loadingFeedback && _feedbackError != null)
          _InlineInfo(
            icon: Icons.info_outline,
            label:
                '${t.translate('coach_habits_load_failed')}: $_feedbackError',
          ),
        if (!_loadingFeedback &&
            _feedbackError == null &&
            _feedbackItems.isEmpty)
          const _InlineInfo(
            icon: Icons.chat_bubble_outline,
            label: 'No coach replies yet.',
          ),
        if (!_loadingFeedback && _feedbackError == null)
          ..._feedbackItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FeedbackEntryCard(
                dateLabel: _formatFeedDate(_feedbackTime(item)),
                workoutLabel: item.exerciseName,
                message: _feedbackMessage(item),
                footerLabel: _isPinned(item)
                    ? 'Pinned by coach'
                    : 'Coach reply',
                isVoiceNote: false,
                hasNutritionNote: false,
                isPinned: _isPinned(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoachTasksCard extends StatelessWidget {
  const _CoachTasksCard({
    required this.title,
    required this.subtitle,
    required this.dailyHabitsTitle,
    required this.pinnedCorrectionsTitle,
    required this.habits,
    required this.loadingHabits,
    required this.habitsError,
    required this.emptyHabitsLabel,
    required this.loadFailedLabel,
    required this.onHabitToggle,
    required this.updatingHabitIds,
    required this.corrections,
    required this.emptyPinnedLabel,
  });

  final String title;
  final String subtitle;
  final String dailyHabitsTitle;
  final String pinnedCorrectionsTitle;
  final List<CoachHabitItem> habits;
  final bool loadingHabits;
  final String? habitsError;
  final String emptyHabitsLabel;
  final String loadFailedLabel;
  final ValueChanged<CoachHabitItem> onHabitToggle;
  final Set<int> updatingHabitIds;
  final List<_PinnedCorrection> corrections;
  final String emptyPinnedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _SectionTitle(label: dailyHabitsTitle),
          const SizedBox(height: 8),
          if (loadingHabits)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (!loadingHabits && habitsError != null)
            _InlineInfo(
              icon: Icons.info_outline,
              label: '$loadFailedLabel: $habitsError',
            ),
          if (!loadingHabits && habitsError == null && habits.isEmpty)
            _InlineInfo(icon: Icons.inbox_outlined, label: emptyHabitsLabel),
          if (!loadingHabits && habitsError == null)
            ...habits.map(
              (habit) => _HabitRow(
                habit: habit,
                isUpdating: updatingHabitIds.contains(habit.id),
                onTap: () => onHabitToggle(habit),
              ),
            ),
          const SizedBox(height: 10),
          _SectionTitle(label: pinnedCorrectionsTitle),
          const SizedBox(height: 8),
          if (corrections.isEmpty)
            _InlineInfo(icon: Icons.push_pin_outlined, label: emptyPinnedLabel),
          ...corrections.map(
            (correction) => _PinnedCorrectionRow(correction: correction),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.isUpdating,
    required this.onTap,
  });

  final CoachHabitItem habit;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isUpdating ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              if (isUpdating)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                Icon(
                  habit.isCompleted
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: habit.isCompleted ? AppColors.accent : Colors.white54,
                  size: 18,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  habit.habit,
                  style: TextStyle(
                    color: habit.isCompleted ? Colors.white54 : Colors.white70,
                    decoration: habit.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedCorrectionRow extends StatelessWidget {
  const _PinnedCorrectionRow({required this.correction});

  final _PinnedCorrection correction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_outlined,
            color: Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correction.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  correction.exercise,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({
    required this.dateLabel,
    required this.workoutLabel,
    required this.message,
    required this.footerLabel,
    required this.isVoiceNote,
    required this.hasNutritionNote,
    required this.isPinned,
  });

  final String dateLabel;
  final String workoutLabel;
  final String message;
  final String footerLabel;
  final bool isVoiceNote;
  final bool hasNutritionNote;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  workoutLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                dateLabel,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                label: isVoiceNote
                    ? t.translate('coach_chip_voice_note')
                    : t.translate('coach_chip_text_note'),
              ),
              if (hasNutritionNote)
                _MetaChip(label: t.translate('coach_chip_nutrition_note')),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.mode_comment_outlined,
                color: isPinned ? Colors.orangeAccent : Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                footerLabel,
                style: TextStyle(
                  color: isPinned ? Colors.orangeAccent : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _PinnedCorrection {
  const _PinnedCorrection({required this.title, required this.exercise});

  final String title;
  final String exercise;
}
