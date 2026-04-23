import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/coach_habits_service.dart';
import '../../services/coach/form_check_service.dart';
import '../../services/coach/voice_note_audio_service.dart';
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
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _voicePlayerSub;
  String? _activeVoiceNoteUrl;
  String? _loadingVoiceNoteUrl;
  String? _completedVoiceNoteUrl;

  @override
  void initState() {
    super.initState();
    _voicePlayerSub = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state.processingState == ProcessingState.completed &&
            _activeVoiceNoteUrl != null) {
          _completedVoiceNoteUrl = _activeVoiceNoteUrl;
        }
      });
    });
    _loadHabits();
    _loadFeedbackFeed();
  }

  @override
  void dispose() {
    _voicePlayerSub?.cancel();
    unawaited(_voicePlayer.dispose());
    super.dispose();
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
        _loadingFeedback = false;
        _feedbackError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackItems = const [];
        _loadingFeedback = false;
        _feedbackError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatFeedDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _entryWorkoutLabel(FormCheckSubmission item) {
    final workoutLabel = item.exerciseName.trim();
    if (workoutLabel.isNotEmpty) return workoutLabel;
    return 'Exercise';
  }

  bool _hasVoiceNote(FormCheckCoachReview? review) {
    final voiceNoteUrl = review?.voiceNoteUrl?.trim() ?? '';
    return voiceNoteUrl.isNotEmpty;
  }

  String _normalizeVoiceNoteUrl(String? rawUrl) => (rawUrl ?? '').trim();

  String _canonicalVoiceNoteKey(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return '';
    final resolved = VoiceNoteAudioService.resolveUri(normalized);
    final parsed = resolved ?? Uri.tryParse(normalized);
    if (parsed == null) {
      final noQuery = normalized.split('?').first.trim();
      return noQuery.isEmpty ? normalized : noQuery;
    }
    final clean = parsed.replace(query: null, fragment: null);
    final scheme = clean.scheme.toLowerCase();
    final host = clean.host.toLowerCase();
    final port = clean.hasPort ? ':${clean.port}' : '';
    if (scheme.isNotEmpty && host.isNotEmpty) {
      return '$scheme://$host$port${clean.path}';
    }
    return clean.path.isEmpty ? normalized : clean.path;
  }

  bool _isVoiceNoteLoading(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    return _loadingVoiceNoteUrl == normalized;
  }

  bool _isVoiceNotePlaying(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    if (_activeVoiceNoteUrl != normalized) return false;
    return _voicePlayer.playing &&
        _voicePlayer.processingState != ProcessingState.completed;
  }

  bool _isVoiceNoteCompleted(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    return _completedVoiceNoteUrl == normalized &&
        _activeVoiceNoteUrl == normalized &&
        _voicePlayer.processingState == ProcessingState.completed;
  }

  Future<void> _toggleVoiceNotePlayback(String? rawUrl) async {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return;

    if (_activeVoiceNoteUrl == normalized) {
      if (_isVoiceNoteCompleted(normalized)) {
        await _voicePlayer.seek(Duration.zero);
        if (mounted) {
          setState(() => _completedVoiceNoteUrl = null);
        } else {
          _completedVoiceNoteUrl = null;
        }
        await _voicePlayer.play();
        return;
      }
      if (_voicePlayer.playing) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play();
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingVoiceNoteUrl = normalized);
    } else {
      _loadingVoiceNoteUrl = normalized;
    }
    try {
      await _voicePlayer.stop();
      final localPath = await VoiceNoteAudioService.prepareLocalVoiceNoteFile(
        normalized,
      );
      await _voicePlayer.setFilePath(localPath);
      if (mounted) {
        setState(() {
          _activeVoiceNoteUrl = normalized;
          _completedVoiceNoteUrl = null;
        });
      } else {
        _activeVoiceNoteUrl = normalized;
        _completedVoiceNoteUrl = null;
      }
      await _voicePlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingVoiceNoteUrl == normalized) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else if (_loadingVoiceNoteUrl == normalized) {
        _loadingVoiceNoteUrl = null;
      }
    }
  }

  bool _isNutritionRelatedEntry(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized.contains('nutrition') ||
        normalized.contains('meal') ||
        normalized.contains('calorie') ||
        normalized.contains('macro');
  }

  List<_FeedbackReplyEntry> _buildFeedbackEntries() {
    final entries = <_FeedbackReplyEntry>[];
    for (final item in _feedbackItems) {
      final workoutLabel = _entryWorkoutLabel(item);
      final hasNutritionNote = _isNutritionRelatedEntry(item.exerciseName);
      var hasRenderableReplies = false;
      final replyVoiceKeys = <String>{};
      final seenReplyIds = <int>{};
      for (final reply in item.coachReviewReplies) {
        if (!seenReplyIds.add(reply.replyId)) continue;
        final text = reply.replyText.trim();
        final replyVoiceUrl = _normalizeVoiceNoteUrl(reply.voiceNoteUrl);
        final hasVoiceReply = replyVoiceUrl.isNotEmpty;
        if (text.isEmpty && !hasVoiceReply) continue;
        hasRenderableReplies = true;
        if (hasVoiceReply) {
          replyVoiceKeys.add(_canonicalVoiceNoteKey(replyVoiceUrl));
        }
        entries.add(
          _FeedbackReplyEntry(
            workoutLabel: workoutLabel,
            message: text.isNotEmpty ? text : 'Voice note from coach.',
            timestamp:
                reply.createdAt ??
                reply.updatedAt ??
                item.updatedAt ??
                item.sharedAt ??
                item.createdAt,
            isVoiceNote: hasVoiceReply,
            hasNutritionNote: hasNutritionNote,
            isPinned: reply.isPinned,
            voiceNoteUrl: hasVoiceReply ? reply.voiceNoteUrl : null,
          ),
        );
      }
      final review = item.coachReview;
      final hasVoiceNote = _hasVoiceNote(review);
      final fallbackText = (item.coachReview?.reviewText ?? '').trim();
      final reviewVoiceKey = _canonicalVoiceNoteKey(
        review?.voiceNoteUrl,
      );
      final reviewHasRenderableContent =
          fallbackText.isNotEmpty || hasVoiceNote;
      final hasLegacyReviewVoiceNote =
          hasVoiceNote && !replyVoiceKeys.contains(reviewVoiceKey);
      final shouldIncludeReviewEntry =
          reviewHasRenderableContent &&
          (!hasRenderableReplies || hasLegacyReviewVoiceNote);
      if (shouldIncludeReviewEntry) {
        entries.add(
          _FeedbackReplyEntry(
            workoutLabel: workoutLabel,
            message: fallbackText.isNotEmpty
                ? fallbackText
                : 'Voice note from coach.',
            timestamp:
                review?.reviewedAt ??
                review?.createdAt ??
                review?.updatedAt ??
                item.updatedAt ??
                item.sharedAt ??
                item.createdAt,
            isVoiceNote: hasVoiceNote,
            hasNutritionNote: hasNutritionNote,
            isPinned: review?.isPinned == true,
            voiceNoteUrl: hasVoiceNote ? review?.voiceNoteUrl : null,
          ),
        );
      }
    }
    entries.sort((a, b) {
      final aTs = a.timestamp;
      final bTs = b.timestamp;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final feedbackEntries = _buildFeedbackEntries();
    final pinnedCorrections = feedbackEntries
        .where((entry) => entry.isPinned)
        .map(
          (entry) => _PinnedCorrection(
            title: entry.message,
            exercise: entry.workoutLabel,
            dateLabel: _formatFeedDate(entry.timestamp),
            isVoiceNote: entry.isVoiceNote,
            hasNutritionNote: entry.hasNutritionNote,
            voiceNoteUrl: entry.voiceNoteUrl,
          ),
        )
        .toList();
    final nonPinnedFeedbackEntries = feedbackEntries
        .where((entry) => !entry.isPinned)
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
          isVoiceLoading: _isVoiceNoteLoading,
          isVoicePlaying: _isVoiceNotePlaying,
          onVoiceToggle: _toggleVoiceNotePlayback,
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
            nonPinnedFeedbackEntries.isEmpty)
          const _InlineInfo(
            icon: Icons.chat_bubble_outline,
            label: 'No coach replies yet.',
          ),
        if (!_loadingFeedback && _feedbackError == null)
          ...nonPinnedFeedbackEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FeedbackEntryCard(
                dateLabel: _formatFeedDate(entry.timestamp),
                workoutLabel: entry.workoutLabel,
                message: entry.message,
                isVoiceNote: entry.isVoiceNote,
                hasNutritionNote: entry.hasNutritionNote,
                isPinned: entry.isPinned,
                isVoiceLoading: _isVoiceNoteLoading(entry.voiceNoteUrl),
                isVoicePlaying: _isVoiceNotePlaying(entry.voiceNoteUrl),
                onVoiceToggle: entry.isVoiceNote
                    ? () => _toggleVoiceNotePlayback(entry.voiceNoteUrl)
                    : null,
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
    required this.isVoiceLoading,
    required this.isVoicePlaying,
    required this.onVoiceToggle,
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
  final bool Function(String?) isVoiceLoading;
  final bool Function(String?) isVoicePlaying;
  final Future<void> Function(String?) onVoiceToggle;

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
            (correction) => _PinnedCorrectionRow(
              correction: correction,
              isVoiceLoading: isVoiceLoading(correction.voiceNoteUrl),
              isVoicePlaying: isVoicePlaying(correction.voiceNoteUrl),
              onVoiceToggle: correction.isVoiceNote
                  ? () => onVoiceToggle(correction.voiceNoteUrl)
                  : null,
            ),
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
  const _PinnedCorrectionRow({
    required this.correction,
    required this.isVoiceLoading,
    required this.isVoicePlaying,
    this.onVoiceToggle,
  });

  final _PinnedCorrection correction;
  final bool isVoiceLoading;
  final bool isVoicePlaying;
  final VoidCallback? onVoiceToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: _FeedbackEntryCard(
        dateLabel: correction.dateLabel,
        workoutLabel: correction.exercise,
        message: correction.title,
        isVoiceNote: correction.isVoiceNote,
        hasNutritionNote: correction.hasNutritionNote,
        isPinned: true,
        isVoiceLoading: isVoiceLoading,
        isVoicePlaying: isVoicePlaying,
        onVoiceToggle: onVoiceToggle,
      ),
    );
  }
}

class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({
    required this.dateLabel,
    required this.workoutLabel,
    required this.message,
    required this.isVoiceNote,
    required this.hasNutritionNote,
    required this.isPinned,
    required this.isVoiceLoading,
    required this.isVoicePlaying,
    this.onVoiceToggle,
  });

  final String dateLabel;
  final String workoutLabel;
  final String message;
  final bool isVoiceNote;
  final bool hasNutritionNote;
  final bool isPinned;
  final bool isVoiceLoading;
  final bool isVoicePlaying;
  final VoidCallback? onVoiceToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final statusIcon = isPinned ? Icons.push_pin : Icons.mode_comment_outlined;
    final statusColor = isPinned ? Colors.orangeAccent : Colors.white54;
    final statusLabel = isPinned ? 'Pinned reply' : 'Coach reply';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 4,
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
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isVoiceNote && onVoiceToggle != null) ...[
                TextButton.icon(
                  onPressed: isVoiceLoading ? null : onVoiceToggle,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3,
                    ),
                  ),
                  icon: isVoiceLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : (isVoicePlaying
                            ? const _AudioWaveBars(
                                color: Colors.white70,
                                barCount: 4,
                                minHeight: 4,
                                maxHeight: 12,
                                barWidth: 2.5,
                                gap: 1.5,
                              )
                            : const Icon(Icons.play_arrow, size: 16)),
                  label: Text(isVoicePlaying ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: 6),
              ],
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _AudioWaveBars extends StatefulWidget {
  const _AudioWaveBars({
    required this.color,
    this.barCount = 5,
    this.minHeight = 4,
    this.maxHeight = 12,
    this.barWidth = 3,
    this.gap = 2,
  });

  final Color color;
  final int barCount;
  final double minHeight;
  final double maxHeight;
  final double barWidth;
  final double gap;

  @override
  State<_AudioWaveBars> createState() => _AudioWaveBarsState();
}

class _AudioWaveBarsState extends State<_AudioWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.barCount, (index) {
            final phase = t + (index * 0.7);
            final level = (math.sin(phase) + 1) / 2;
            final height =
                widget.minHeight +
                (widget.maxHeight - widget.minHeight) * level;
            return Padding(
              padding: EdgeInsets.only(
                right: index == widget.barCount - 1 ? 0 : widget.gap,
              ),
              child: Container(
                width: widget.barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PinnedCorrection {
  const _PinnedCorrection({
    required this.title,
    required this.exercise,
    required this.dateLabel,
    required this.isVoiceNote,
    required this.hasNutritionNote,
    required this.voiceNoteUrl,
  });

  final String title;
  final String exercise;
  final String dateLabel;
  final bool isVoiceNote;
  final bool hasNutritionNote;
  final String? voiceNoteUrl;
}

class _FeedbackReplyEntry {
  const _FeedbackReplyEntry({
    required this.workoutLabel,
    required this.message,
    required this.timestamp,
    required this.isVoiceNote,
    required this.hasNutritionNote,
    required this.isPinned,
    required this.voiceNoteUrl,
  });

  final String workoutLabel;
  final String message;
  final DateTime? timestamp;
  final bool isVoiceNote;
  final bool hasNutritionNote;
  final bool isPinned;
  final String? voiceNoteUrl;
}
