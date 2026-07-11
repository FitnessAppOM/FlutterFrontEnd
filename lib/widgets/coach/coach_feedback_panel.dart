import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/account_storage.dart';
import '../../core/user_friendly_error.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/coach_habits_service.dart';
import '../../services/coach/diet_document_file_service.dart';
import '../../services/coach/form_check_service.dart';
import '../../services/coach/voice_note_audio_service.dart';
import '../../services/core/pdf_open_service.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_mini_tag.dart';
import '../../TaqaUI/components/taqa_refresh_indicator.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

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
  List<DietFeedbackComment> _dietFeedbackComments = const [];
  List<DietFeedbackDocument> _dietFeedbackDocuments = const [];
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
        _habitsError = userFriendlyErrorMessage(
          e,
          fallback: 'Could not load habits. Please try again.',
        );
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
        _dietFeedbackComments = feed.dietComments;
        _dietFeedbackDocuments = feed.dietDocuments;
        _loadingFeedback = false;
        _feedbackError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackItems = const [];
        _dietFeedbackComments = const [];
        _dietFeedbackDocuments = const [];
        _loadingFeedback = false;
        _feedbackError = userFriendlyErrorMessage(
          e,
          fallback: 'Could not load feedback. Please try again.',
        );
      });
    }
  }

  Future<void> _openDocument(String? url, {String? suggestedFileName}) async {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) return;
    try {
      final localPath =
          await DietDocumentFileService.prepareLocalDietDocumentFile(
            normalized,
            suggestedFileName: suggestedFileName,
          );
      // PDFs stay in-app via the same viewer used for announcements/diet
      // plans/chat attachments; other document types (doc/docx/txt/rtf)
      // still need an external app that can render them.
      if (PdfOpenService.isPdfUrl(
            normalized,
            suggestedFileName: suggestedFileName,
          ) ||
          localPath.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        await PdfOpenService.openLocalFile(
          context,
          path: localPath,
          title: suggestedFileName ?? 'Document',
        );
        return;
      }

      var opened = false;
      try {
        opened = await launchUrl(
          Uri.file(localPath),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        final remoteUri = DietDocumentFileService.resolveUri(normalized);
        if (remoteUri != null) {
          opened = await launchUrl(
            remoteUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      if (!opened) {
        throw Exception('Could not open downloaded document on this device.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFriendlyErrorMessage(
              e,
              fallback: 'Could not open document right now.',
            ),
          ),
        ),
      );
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
          SnackBar(
            content: Text(
              userFriendlyErrorMessage(
                e,
                fallback: 'Could not play voice note right now.',
              ),
            ),
          ),
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
            isDocument: false,
            hasNutritionNote: hasNutritionNote,
            hasVideoNote: true,
            isPinned: reply.isPinned,
            isNew: reply.clientSeenAt == null,
            voiceNoteUrl: hasVoiceReply ? reply.voiceNoteUrl : null,
            documentUrl: null,
            documentFileName: null,
          ),
        );
      }
      final review = item.coachReview;
      final hasVoiceNote = _hasVoiceNote(review);
      final fallbackText = (item.coachReview?.reviewText ?? '').trim();
      final reviewVoiceKey = _canonicalVoiceNoteKey(review?.voiceNoteUrl);
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
            isDocument: false,
            hasNutritionNote: hasNutritionNote,
            hasVideoNote: true,
            isPinned: review?.isPinned == true,
            isNew: review?.clientSeenAt == null,
            voiceNoteUrl: hasVoiceNote ? review?.voiceNoteUrl : null,
            documentUrl: null,
            documentFileName: null,
          ),
        );
      }
    }
    for (final comment in _dietFeedbackComments) {
      final mealDate = comment.mealDate.trim();
      final mealTitle = (comment.mealTitle ?? '').trim();
      final mealSuffix = mealTitle.isNotEmpty
          ? mealTitle
          : (comment.mealIndex != null ? 'Meal ${comment.mealIndex}' : '');
      final labelParts = <String>[];
      if (mealDate.isNotEmpty) {
        labelParts.add(mealDate);
      }
      if (mealSuffix.isNotEmpty) {
        labelParts.add(mealSuffix);
      }
      final label = labelParts.isEmpty ? 'Meal' : labelParts.join(' • ');
      final voiceUrl = _normalizeVoiceNoteUrl(comment.voiceNoteUrl);
      final hasVoice = voiceUrl.isNotEmpty;
      final text = comment.commentText.trim();
      entries.add(
        _FeedbackReplyEntry(
          workoutLabel: label,
          message: text.isNotEmpty ? text : 'Voice note from coach.',
          timestamp: comment.createdAt ?? comment.updatedAt,
          isVoiceNote: hasVoice,
          isDocument: false,
          hasNutritionNote: true,
          hasVideoNote: false,
          isPinned: comment.isPinned,
          isNew: comment.clientSeenAt == null,
          voiceNoteUrl: hasVoice ? comment.voiceNoteUrl : null,
          documentUrl: null,
          documentFileName: null,
        ),
      );
    }
    for (final document in _dietFeedbackDocuments) {
      final title = (document.documentTitle ?? '').trim();
      final originalName = (document.originalFilename ?? '').trim();
      final label = title.isNotEmpty
          ? title
          : (originalName.isNotEmpty ? originalName : 'Diet document');
      final url = (document.documentUrl ?? '').trim();
      if (url.isEmpty) continue;
      entries.add(
        _FeedbackReplyEntry(
          workoutLabel: 'Diet Document',
          message: label,
          timestamp: document.createdAt ?? document.updatedAt,
          isVoiceNote: false,
          isDocument: true,
          hasNutritionNote: true,
          hasVideoNote: false,
          isPinned: document.isPinned,
          isNew: document.clientSeenAt == null,
          voiceNoteUrl: null,
          documentUrl: url,
          documentFileName: originalName.isNotEmpty ? originalName : null,
        ),
      );
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
            isDocument: entry.isDocument,
            hasNutritionNote: entry.hasNutritionNote,
            hasVideoNote: entry.hasVideoNote,
            isNew: entry.isNew,
            voiceNoteUrl: entry.voiceNoteUrl,
            documentUrl: entry.documentUrl,
            documentFileName: entry.documentFileName,
          ),
        )
        .toList();
    final nonPinnedFeedbackEntries = feedbackEntries
        .where((entry) => !entry.isPinned)
        .toList();

    return TaqaRefreshIndicator(
      onRefresh: () => Future.wait([_loadHabits(), _loadFeedbackFeed()]),
      child: ListView(
      padding: TaqaUiScale.insetsLTRB(20, 20, 20, 24),
      children: [
        Text(
          t.translate('coach_tasks_title'),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(25),
            fontWeight: FontWeight.w700,
            height: 25 / 25,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(5)),
        Text(
          t.translate('coach_tasks_subtitle'),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w400,
            height: 18 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        SizedBox(height: TaqaUiScale.h(20)),
        _TaskSectionCard(
          title: t.translate('coach_tasks_daily_habits'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingHabits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaqaUiColors.lime,
                      ),
                    ),
                  ),
                ),
              if (!_loadingHabits && _habitsError != null)
                _InlineInfo(
                  icon: Icons.info_outline,
                  label:
                      '${t.translate('coach_habits_load_failed')}: $_habitsError',
                ),
              if (!_loadingHabits && _habitsError == null && _habits.isEmpty)
                _InlineInfo(
                  icon: Icons.inbox_outlined,
                  label: t.translate('coach_habits_empty'),
                ),
              if (!_loadingHabits && _habitsError == null)
                ..._habits.map(
                  (habit) => _HabitRow(
                    habit: habit,
                    isUpdating: _updatingHabitIds.contains(habit.id),
                    onTap: () => _toggleHabit(habit),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: TaqaUiScale.h(14)),
        _TaskSectionCard(
          title: t.translate('coach_tasks_pinned_corrections'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pinnedCorrections.isEmpty)
                const _InlineInfo(
                  icon: Icons.push_pin_outlined,
                  label: 'No pinned replies yet.',
                ),
              ...pinnedCorrections.map(
                (correction) => _PinnedCorrectionRow(
                  correction: correction,
                  isVoiceLoading: _isVoiceNoteLoading(correction.voiceNoteUrl),
                  isVoicePlaying: _isVoiceNotePlaying(correction.voiceNoteUrl),
                  onVoiceToggle: correction.isVoiceNote
                      ? () => _toggleVoiceNotePlayback(correction.voiceNoteUrl)
                      : null,
                  onOpenDocument: correction.isDocument
                      ? () => _openDocument(
                          correction.documentUrl,
                          suggestedFileName: correction.documentFileName,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: TaqaUiScale.h(14)),
        _TaskSectionCard(
          title: t.translate('coach_feedback_feed_title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingFeedback)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TaqaUiColors.lime,
                      ),
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
                      isDocument: entry.isDocument,
                      hasNutritionNote: entry.hasNutritionNote,
                      hasVideoNote: entry.hasVideoNote,
                      isPinned: entry.isPinned,
                      isNew: entry.isNew,
                      isVoiceLoading: _isVoiceNoteLoading(entry.voiceNoteUrl),
                      isVoicePlaying: _isVoiceNotePlaying(entry.voiceNoteUrl),
                      onVoiceToggle: entry.isVoiceNote
                          ? () => _toggleVoiceNotePlayback(entry.voiceNoteUrl)
                          : null,
                      onOpenDocument: entry.isDocument
                          ? () => _openDocument(
                              entry.documentUrl,
                              suggestedFileName: entry.documentFileName,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// White rounded card with a bold title and arbitrary content — shared
/// shell for the Habits / Active Pinned Corrections / Feedback Feed
/// sections on the coach tasks screen.
class _TaskSectionCard extends StatelessWidget {
  const _TaskSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              height: 25 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          child,
        ],
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
    final typeLabel = habit.isDaily ? 'Daily' : 'Weekly';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isUpdating ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                if (isUpdating)
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqaUiColors.lime,
                    ),
                  )
                else
                  Icon(
                    habit.isCompleted
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: habit.isCompleted
                        ? TaqaUiColors.lime
                        : TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.35,
                          ),
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    habit.habit,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: habit.isCompleted ? 0.4 : 0.85,
                      ),
                      decoration: habit.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TaqaMiniTag(label: typeLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.label});

  // Kept so call sites don't need to change; no longer rendered — these
  // empty-state rows are plain text now, no icon, no background chip.
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          color: TaqaUiColors.unnamedColor1c1d17,
          fontSize: TaqaUiScale.sp(15),
          fontWeight: FontWeight.w400,
          height: 21 / 15,
          letterSpacing: 0,
        ),
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
    this.onOpenDocument,
  });

  final _PinnedCorrection correction;
  final bool isVoiceLoading;
  final bool isVoicePlaying;
  final VoidCallback? onVoiceToggle;
  final VoidCallback? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: _FeedbackEntryCard(
        dateLabel: correction.dateLabel,
        workoutLabel: correction.exercise,
        message: correction.title,
        isVoiceNote: correction.isVoiceNote,
        isDocument: correction.isDocument,
        hasNutritionNote: correction.hasNutritionNote,
        hasVideoNote: correction.hasVideoNote,
        isPinned: true,
        isNew: correction.isNew,
        isVoiceLoading: isVoiceLoading,
        isVoicePlaying: isVoicePlaying,
        onVoiceToggle: onVoiceToggle,
        onOpenDocument: onOpenDocument,
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
    required this.isDocument,
    required this.hasNutritionNote,
    required this.hasVideoNote,
    required this.isPinned,
    required this.isNew,
    required this.isVoiceLoading,
    required this.isVoicePlaying,
    this.onVoiceToggle,
    this.onOpenDocument,
  });

  final String dateLabel;
  final String workoutLabel;
  final String message;
  final bool isVoiceNote;
  final bool isDocument;
  final bool hasNutritionNote;
  final bool hasVideoNote;
  final bool isPinned;
  final bool isNew;
  final bool isVoiceLoading;
  final bool isVoicePlaying;
  final VoidCallback? onVoiceToggle;
  final VoidCallback? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final statusIcon = isPinned ? Icons.push_pin : Icons.mode_comment_outlined;
    final statusColor = isPinned
        ? Colors.orange.shade700
        : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5);
    final statusLabel = isPinned ? 'Pinned reply' : 'Coach reply';
    final textButtonStyle = TextButton.styleFrom(
      foregroundColor: TaqaUiColors.unnamedColor1c1d17,
      minimumSize: const Size(0, 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.08),
            ),
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
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        color: TaqaUiColors.unnamedColor1c1d17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: TaqaUiScale.sp(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  TaqaMiniTag(
                    label: isVoiceNote
                        ? t.translate('coach_chip_voice_note')
                        : (isDocument
                              ? 'Document'
                              : t.translate('coach_chip_text_note')),
                  ),
                  if (hasNutritionNote)
                    TaqaMiniTag(label: t.translate('coach_chip_nutrition_note')),
                  if (hasVideoNote)
                    TaqaMiniTag(label: t.translate('coach_chip_video_note')),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isVoiceNote && onVoiceToggle != null) ...[
                    TextButton.icon(
                      onPressed: isVoiceLoading ? null : onVoiceToggle,
                      style: textButtonStyle,
                      icon: isVoiceLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.6),
                              ),
                            )
                          : (isVoicePlaying
                                ? _AudioWaveBars(
                                    color: TaqaUiColors.unnamedColor1c1d17
                                        .withValues(alpha: 0.6),
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
                  if (isDocument && onOpenDocument != null) ...[
                    TextButton.icon(
                      onPressed: onOpenDocument,
                      style: textButtonStyle,
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text('Open'),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: statusColor,
                      fontSize: TaqaUiScale.sp(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isNew)
          Positioned(
            top: -8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
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
    required this.isDocument,
    required this.hasNutritionNote,
    required this.hasVideoNote,
    required this.isNew,
    required this.voiceNoteUrl,
    required this.documentUrl,
    required this.documentFileName,
  });

  final String title;
  final String exercise;
  final String dateLabel;
  final bool isVoiceNote;
  final bool isDocument;
  final bool hasNutritionNote;
  final bool hasVideoNote;
  final bool isNew;
  final String? voiceNoteUrl;
  final String? documentUrl;
  final String? documentFileName;
}

class _FeedbackReplyEntry {
  const _FeedbackReplyEntry({
    required this.workoutLabel,
    required this.message,
    required this.timestamp,
    required this.isVoiceNote,
    required this.isDocument,
    required this.hasNutritionNote,
    required this.hasVideoNote,
    required this.isPinned,
    required this.isNew,
    required this.voiceNoteUrl,
    required this.documentUrl,
    required this.documentFileName,
  });

  final String workoutLabel;
  final String message;
  final DateTime? timestamp;
  final bool isVoiceNote;
  final bool isDocument;
  final bool hasNutritionNote;
  final bool hasVideoNote;
  final bool isPinned;
  final bool isNew;
  final String? voiceNoteUrl;
  final String? documentUrl;
  final String? documentFileName;
}
