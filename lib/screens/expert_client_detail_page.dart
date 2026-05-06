import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../services/auth/profile_service.dart';
import '../services/coach/chat_attachment_file_service.dart';
import '../services/coach/coach_habits_service.dart';
import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/form_check_service.dart';
import '../services/coach/progression_review_service.dart';
import '../services/coach/voice_note_audio_service.dart';
import '../theme/app_theme.dart';
import 'expert_client_analytics_page.dart';
import 'expert_client_chat_page.dart';
import 'expert_client_diet_review_page.dart';
import 'expert_client_habits_page.dart';
import 'expert_progression_review_page.dart';
import '../widgets/coach/chat_video_player_page.dart';

String _aiUpdateGenerationMessage(Map<String, dynamic> result) {
  final reason = (result['reason'] ?? '').toString().trim();
  final detail = (result['detail'] ?? '').toString().trim();
  if (detail.isNotEmpty) return detail;
  switch (reason) {
    case 'insufficient_weekly_activity':
      return 'Need at least 2 logged exercises this week before generating AI updates.';
    case 'no_active_program':
      return 'This client has no active training program.';
    case 'no_assigned_expert':
      return 'No assigned expert found for this client.';
    default:
      return reason.isNotEmpty ? reason : 'No review generated.';
  }
}

class ExpertClientDetailPage extends StatefulWidget {
  const ExpertClientDetailPage({
    super.key,
    required this.client,
    required this.reviews,
    this.onDietLogSeen,
  });

  final ProgressionClient client;
  final List<ProgressionReview> reviews;
  final VoidCallback? onDietLogSeen;

  @override
  State<ExpertClientDetailPage> createState() => _ExpertClientDetailPageState();
}

class _ExpertClientDetailPageState extends State<ExpertClientDetailPage> {
  bool _loading = true;
  int? _expertId;
  Map<String, dynamic>? _profile;
  List<CoachHabitItem> _habits = const [];
  List<ProgressionReview> _clientReviews = const [];
  List<FormCheckSubmission> _sharedFormChecks = const [];
  final Map<int, TextEditingController> _reviewControllers =
      <int, TextEditingController>{};
  final Set<int> _savingReviewIds = <int>{};
  final Set<int> _sendingVoiceNoteIds = <int>{};
  final Set<int> _pinningReviewIds = <int>{};
  final Set<int> _pinningReplyIds = <int>{};
  bool _generatingAiReview = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _voicePlayerSub;
  bool _isRecordingVoiceNote = false;
  int? _recordingVoiceNoteSubmissionId;
  String? _recordingVoiceNotePath;
  int? _pendingVoiceNoteSubmissionId;
  String? _pendingVoiceNotePath;
  String? _activeVoiceNoteUrl;
  String? _loadingVoiceNoteUrl;
  StateSetter? _activeReviewSheetSetState;
  String? _profileError;
  String? _habitsError;
  String? _formChecksError;
  bool _detachingClient = false;
  bool _reportingClient = false;
  late bool _showFormReviewPendingNote;
  late bool _showDietLogPendingNote;
  late bool _showTrainingPlanPendingNote;
  bool _dietLogSeenNotified = false;
  bool _supportChatHasUnread = false;

  @override
  void initState() {
    super.initState();
    _clientReviews = widget.reviews
        .where((review) => review.userId == widget.client.userId)
        .toList();
    _showFormReviewPendingNote = widget.client.hasFormCheckToReview;
    _showDietLogPendingNote = widget.client.hasDietLogToReview;
    _showTrainingPlanPendingNote = widget.client.hasUncheckedTrainingPlan;
    _voicePlayerSub = _voicePlayer.playerStateStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
      final sheetSetState = _activeReviewSheetSetState;
      if (sheetSetState != null) {
        try {
          sheetSetState(() {});
        } catch (_) {}
      }
    });
    _load();
  }

  @override
  void dispose() {
    for (final controller in _reviewControllers.values) {
      controller.dispose();
    }
    final pendingPath = (_pendingVoiceNotePath ?? '').trim();
    if (pendingPath.isNotEmpty) {
      unawaited(_deleteLocalFile(pendingPath));
    }
    _activeReviewSheetSetState = null;
    _voicePlayerSub?.cancel();
    unawaited(_voicePlayer.dispose());
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _profileError = null;
        _habitsError = null;
        _formChecksError = null;
      });
    }

    Map<String, dynamic>? profile;
    List<CoachHabitItem> habits = const [];
    List<FormCheckSubmission> sharedFormChecks = const [];
    int? expertId;
    String? profileError;
    String? habitsError;
    String? formChecksError;
    bool showTrainingPlanPendingNote = _showTrainingPlanPendingNote;
    bool supportChatHasUnread = _supportChatHasUnread;

    try {
      expertId = await AccountStorage.getUserId();
    } catch (_) {
      expertId = null;
    }
    try {
      final status =
          await ProgressionReviewService.fetchClientTrainingPlanSeenStatus(
            clientUserId: widget.client.userId,
          );
      showTrainingPlanPendingNote =
          status['has_unchecked_training_plan'] == true;
    } catch (_) {
      // Keep previous value if status cannot be loaded.
    }

    try {
      profile = await ProfileApi.fetchProfile(widget.client.userId);
    } catch (e) {
      profileError = e.toString();
    }

    try {
      habits = await CoachHabitsService.fetchClientHabits(
        clientId: widget.client.userId,
        expertId: expertId,
        includeCompleted: true,
      );
    } catch (e) {
      habitsError = _normalizeHabitsError(e);
    }

    try {
      sharedFormChecks =
          await ProgressionReviewService.fetchClientSharedFormChecks(
            widget.client.userId,
          );
    } catch (e) {
      formChecksError = _normalizeHabitsError(e);
    }

    try {
      supportChatHasUnread =
          await CoachSupportChatService.fetchCoachClientThreadHasUnread(
            clientUserId: widget.client.userId,
          );
    } catch (_) {
      // Keep previous value if support-chat status cannot be loaded.
    }

    if (!mounted) return;
    _syncReviewControllers(sharedFormChecks);
    setState(() {
      _expertId = expertId;
      _profile = profile;
      _habits = habits;
      _sharedFormChecks = sharedFormChecks;
      _profileError = profileError;
      _habitsError = habitsError;
      _formChecksError = formChecksError;
      _showTrainingPlanPendingNote = showTrainingPlanPendingNote;
      _supportChatHasUnread = supportChatHasUnread;
      _loading = false;
    });
  }

  Future<void> _refreshSupportChatUnreadStatus() async {
    try {
      final hasUnread =
          await CoachSupportChatService.fetchCoachClientThreadHasUnread(
            clientUserId: widget.client.userId,
          );
      if (!mounted) return;
      setState(() {
        _supportChatHasUnread = hasUnread;
      });
    } catch (_) {}
  }

  void _handleTrainingPlanVerified() {
    if (!_showTrainingPlanPendingNote || !mounted) return;
    setState(() {
      _showTrainingPlanPendingNote = false;
    });
  }

  List<ProgressionReview> _clientAiReviews() {
    final items = List<ProgressionReview>.from(_clientReviews);
    items.sort((a, b) {
      final aPriority = a.isPendingExpert
          ? 0
          : a.isReviewed
          ? 1
          : a.isApplied
          ? 2
          : 3;
      final bPriority = b.isPendingExpert
          ? 0
          : b.isReviewed
          ? 1
          : b.isApplied
          ? 2
          : 3;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      final aDate = a.reviewedAt ?? a.appliedAt ?? a.weekStart ?? '';
      final bDate = b.reviewedAt ?? b.appliedAt ?? b.weekStart ?? '';
      return bDate.compareTo(aDate);
    });
    return items;
  }

  bool get _hasAiUpdatesPending =>
      _showFormReviewPendingNote || _showTrainingPlanPendingNote;

  int get _pendingAiUpdateCount {
    var count = 0;
    if (_showFormReviewPendingNote) {
      count += math.max(widget.client.sharedFormCheckCount, 1);
    }
    if (_showTrainingPlanPendingNote) {
      count += math.max(widget.client.trainingPlanUncheckedCount, 1);
    }
    return count;
  }

  IconData get _aiUpdatesStatusIcon {
    if (_showFormReviewPendingNote) {
      return Icons.notification_important_outlined;
    }
    return Icons.auto_awesome_rounded;
  }

  Color get _aiUpdatesStatusColor {
    if (_showFormReviewPendingNote) {
      return Colors.orangeAccent;
    }
    return const Color(0xFF5FD8FF);
  }

  String _aiUpdatesStatusText() {
    final hasForm = _showFormReviewPendingNote;
    final hasTraining = _showTrainingPlanPendingNote;
    if (hasForm && hasTraining) {
      final count = _pendingAiUpdateCount;
      return count > 1
          ? 'AI updates pending review ($count)'
          : 'AI update pending review';
    }
    if (hasForm) {
      return widget.client.sharedFormCheckCount > 1
          ? 'Form checks awaiting reply (${widget.client.sharedFormCheckCount})'
          : 'Form check awaiting reply';
    }
    if (hasTraining) {
      return widget.client.trainingPlanUncheckedCount > 1
          ? 'Training suggestions pending review (${widget.client.trainingPlanUncheckedCount})'
          : 'Training suggestions pending review';
    }
    final reviewCount = _clientAiReviews().length;
    return reviewCount > 0
        ? 'Latest AI updates ready'
        : 'No AI updates pending';
  }

  Future<void> _openAiReview(ProgressionReview review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertProgressionReviewPage(reviewId: review.reviewId),
      ),
    );
    await _refreshClientReviews();
    await _load();
  }

  Future<void> _refreshClientReviews() async {
    try {
      final refreshed = await ProgressionReviewService.fetchReviews(
        includeApplied: true,
      );
      if (!mounted) return;
      setState(() {
        _clientReviews = refreshed
            .where((item) => item.userId == widget.client.userId)
            .toList();
      });
    } catch (_) {
      // Keep the updated detail page usable even if the refresh fails.
    }
  }

  Future<void> _generateAiReview({required bool force}) async {
    if (_generatingAiReview) return;
    setState(() => _generatingAiReview = true);
    try {
      final result = await ProgressionReviewService.generateReview(
        widget.client.userId,
        force: force,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString();
      String message;
      switch (status) {
        case 'generated':
          message = 'AI update review generated.';
          break;
        case 'exists':
          message = 'A review already exists for this week.';
          break;
        case 'noop':
          message = _aiUpdateGenerationMessage(result);
          break;
        case 'failed':
          message =
              (result['detail'] ?? result['reason'] ?? 'Generation failed.')
                  .toString();
          break;
        default:
          message = (result['detail'] ?? 'AI update request completed.')
              .toString();
          break;
      }
      _showSnack(message);
      await _refreshClientReviews();
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _generatingAiReview = false);
      }
    }
  }

  Future<void> _openAiUpdatesPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientAiUpdatesPage(
          client: widget.client,
          onOpenFormCheck: (item) => _openSubmissionReviewSheet(item),
        ),
      ),
    );
    await _load();
  }

  String _normalizeHabitsError(Object error) {
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

  String _displayName() {
    final fromClient = (widget.client.name ?? '').trim();
    if (fromClient.isNotEmpty) return fromClient;
    final fromProfile = ((_profile?['full_name'] ?? _profile?['name']) ?? '')
        .toString()
        .trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    return 'Client #${widget.client.userId}';
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String? _normalizeAvatarUrl(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower == 'null' || lower == 'none') return null;
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return null;
    }
  }

  String? _resolvedAvatarUrl() {
    return _normalizeAvatarUrl(widget.client.avatarUrl) ??
        _normalizeAvatarUrl(_profile?['avatar_url']?.toString());
  }

  String _value(dynamic raw, {String fallback = '-'}) {
    final text = (raw ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Color _activityColor() {
    switch ((widget.client.activityStatus ?? '').trim().toLowerCase()) {
      case 'green':
        return Colors.greenAccent.shade400;
      case 'yellow':
        return Colors.amber.shade400;
      case 'red':
        return Colors.redAccent.shade200;
      default:
        return Colors.redAccent.shade200;
    }
  }

  String _activityLabel() {
    final status = (widget.client.activityStatus ?? '').trim().toLowerCase();
    if (status == 'green') return 'Active';
    if (status == 'yellow') {
      if (widget.client.inactiveDays != null) {
        return 'Inactive ${widget.client.inactiveDays} days';
      }
      return 'Inactive 3+ days';
    }
    if (widget.client.inactiveDays != null) {
      return 'Inactive ${widget.client.inactiveDays} days';
    }
    return 'Inactive 7+ days';
  }

  Future<void> _openVideoInApp(String? url, {required String title}) async {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) return;
    try {
      final localPath =
          await ChatAttachmentFileService.prepareLocalAttachmentFile(
            normalized,
            suggestedFileName: '$title.mp4',
            fallbackExtension: '.mp4',
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatVideoPlayerPage(videoPath: localPath, title: title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Could not open video: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _syncReviewControllers(List<FormCheckSubmission> items) {
    final activeIds = items.map((item) => item.submissionId).toSet();
    final staleIds = _reviewControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _reviewControllers.remove(id)?.dispose();
    }
  }

  TextEditingController _reviewControllerFor(FormCheckSubmission item) {
    final existing = _reviewControllers[item.submissionId];
    if (existing != null) return existing;
    final created = TextEditingController();
    _reviewControllers[item.submissionId] = created;
    return created;
  }

  void _replaceFormCheckItem(FormCheckSubmission updated) {
    _sharedFormChecks = _sharedFormChecks
        .map(
          (item) => item.submissionId == updated.submissionId ? updated : item,
        )
        .toList();
    _syncReviewControllers(_sharedFormChecks);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _detachClient() async {
    if (_detachingClient) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detach client?'),
        content: const Text(
          'Are you sure you want to detach this client from your coaching list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Detach'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _detachingClient = true);
    try {
      await ProgressionReviewService.detachClient(
        clientUserId: widget.client.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _detachingClient = false);
      }
    }
  }

  Future<void> _reportClient() async {
    if (_reportingClient) return;
    final reasonController = TextEditingController();
    String? errorText;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please write the reason for this report.'),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Write the reason...',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => errorText = 'Reason is required.');
                  return;
                }
                Navigator.of(ctx).pop(value);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    setState(() => _reportingClient = true);
    try {
      await ProgressionReviewService.reportClient(
        clientUserId: widget.client.userId,
        reason: reason,
      );
      if (!mounted) return;
      _showSnack('Client report submitted. Our team will review it.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _reportingClient = false);
      }
    }
  }

  void _refreshOpenReviewSheet() {
    final sheetSetState = _activeReviewSheetSetState;
    if (sheetSetState != null) {
      try {
        sheetSetState(() {});
      } catch (_) {}
    }
  }

  String _normalizeVoiceNoteUrl(String? rawUrl) => (rawUrl ?? '').trim();

  String _pendingVoiceSourceKey(String path) => 'local:${path.trim()}';

  bool _isVoiceNoteLoading(String rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    return _loadingVoiceNoteUrl == normalized;
  }

  bool _isVoiceNotePlaying(String rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    if (_activeVoiceNoteUrl != normalized) return false;
    return _voicePlayer.playing &&
        _voicePlayer.processingState != ProcessingState.completed;
  }

  Future<void> _toggleVoiceNotePlayback(String rawUrl) async {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return;

    if (_activeVoiceNoteUrl == normalized) {
      if (_voicePlayer.processingState == ProcessingState.completed) {
        await _voicePlayer.seek(Duration.zero);
        await _voicePlayer.play();
        _refreshOpenReviewSheet();
        return;
      }
      if (_voicePlayer.playing) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play();
      }
      _refreshOpenReviewSheet();
      return;
    }

    setState(() {
      _loadingVoiceNoteUrl = normalized;
    });
    _refreshOpenReviewSheet();
    try {
      await _voicePlayer.stop();
      final localFilePath =
          await VoiceNoteAudioService.prepareLocalVoiceNoteFile(normalized);
      await _voicePlayer.setFilePath(localFilePath);
      _activeVoiceNoteUrl = normalized;
      await _voicePlayer.play();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
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
      _refreshOpenReviewSheet();
    }
  }

  Future<void> _togglePendingVoiceNotePlayback(String localPath) async {
    final normalizedPath = localPath.trim();
    if (normalizedPath.isEmpty) return;
    final sourceKey = _pendingVoiceSourceKey(normalizedPath);

    if (_activeVoiceNoteUrl == sourceKey) {
      if (_voicePlayer.processingState == ProcessingState.completed) {
        await _voicePlayer.seek(Duration.zero);
        await _voicePlayer.play();
        _refreshOpenReviewSheet();
        return;
      }
      if (_voicePlayer.playing) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play();
      }
      _refreshOpenReviewSheet();
      return;
    }

    setState(() {
      _loadingVoiceNoteUrl = sourceKey;
    });
    _refreshOpenReviewSheet();
    try {
      await _voicePlayer.stop();
      await _voicePlayer.setFilePath(normalizedPath);
      _activeVoiceNoteUrl = sourceKey;
      await _voicePlayer.play();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingVoiceNoteUrl == sourceKey) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else if (_loadingVoiceNoteUrl == sourceKey) {
        _loadingVoiceNoteUrl = null;
      }
      _refreshOpenReviewSheet();
    }
  }

  Future<FormCheckSubmission?> _saveWrittenReview(
    FormCheckSubmission item,
  ) async {
    final submissionId = item.submissionId;
    if (_savingReviewIds.contains(submissionId)) return null;
    if (_isRecordingVoiceNote &&
        _recordingVoiceNoteSubmissionId == submissionId) {
      _showSnack('Stop recording before sending a text comment.');
      return null;
    }
    if (_hasPendingVoiceNoteForSubmission(submissionId)) {
      _showSnack('Send or cancel the voice note before sending text.');
      return null;
    }

    final controller = _reviewControllerFor(item);
    final reviewText = controller.text.trim();
    if (reviewText.isEmpty) {
      _showSnack('Write your comment before sending.');
      return null;
    }

    setState(() => _savingReviewIds.add(submissionId));
    try {
      final updated = await ProgressionReviewService.submitFormCheckReview(
        submissionId: submissionId,
        reviewText: reviewText,
      );
      if (!mounted) return null;
      setState(() {
        _replaceFormCheckItem(updated);
      });
      controller.clear();
      _showSnack('Comment sent.');
      return updated;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _savingReviewIds.remove(submissionId));
      }
    }
  }

  bool _hasPendingVoiceNoteForSubmission(int submissionId) {
    if (_pendingVoiceNoteSubmissionId != submissionId) return false;
    return (_pendingVoiceNotePath ?? '').trim().isNotEmpty;
  }

  Future<void> _deleteLocalFile(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _clearPendingVoiceNote({
    int? submissionId,
    bool deleteFile = true,
  }) async {
    if (submissionId != null && _pendingVoiceNoteSubmissionId != submissionId) {
      return;
    }
    final pendingPath = (_pendingVoiceNotePath ?? '').trim();
    final pendingKey = pendingPath.isEmpty
        ? null
        : _pendingVoiceSourceKey(pendingPath);
    if (pendingKey != null && _activeVoiceNoteUrl == pendingKey) {
      try {
        await _voicePlayer.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _activeVoiceNoteUrl = null;
          if (_loadingVoiceNoteUrl == pendingKey) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else {
        _activeVoiceNoteUrl = null;
        if (_loadingVoiceNoteUrl == pendingKey) {
          _loadingVoiceNoteUrl = null;
        }
      }
      _refreshOpenReviewSheet();
    }
    if (mounted) {
      setState(() {
        _pendingVoiceNoteSubmissionId = null;
        _pendingVoiceNotePath = null;
      });
    } else {
      _pendingVoiceNoteSubmissionId = null;
      _pendingVoiceNotePath = null;
    }
    if (deleteFile && pendingPath.isNotEmpty) {
      await _deleteLocalFile(pendingPath);
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      final allowedByRecorder = await _audioRecorder.hasPermission();
      if (allowedByRecorder) return true;
    } catch (_) {}

    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied || status.isRestricted) return false;
      status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _startVoiceNoteRecording(FormCheckSubmission item) async {
    final submissionId = item.submissionId;
    if (_sendingVoiceNoteIds.contains(submissionId)) {
      _showSnack('Voice note is still uploading. Please wait.');
      return false;
    }
    if ((_pendingVoiceNotePath ?? '').trim().isNotEmpty) {
      if (_pendingVoiceNoteSubmissionId == submissionId) {
        _showSnack('Send or cancel the current voice note first.');
      } else {
        _showSnack(
          'Send or cancel the current voice note before recording another one.',
        );
      }
      return false;
    }
    if (_isRecordingVoiceNote) {
      _showSnack('A voice note is already recording.');
      return false;
    }

    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      _showSnack(
        'Microphone permission is required. Please enable it in app settings.',
      );
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_note_${submissionId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (e) {
      _showSnack('Could not start voice recording: $e');
      return false;
    }

    if (!mounted) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      return false;
    }

    setState(() {
      _isRecordingVoiceNote = true;
      _recordingVoiceNoteSubmissionId = submissionId;
      _recordingVoiceNotePath = path;
    });
    return true;
  }

  Future<void> _cancelVoiceNoteRecording() async {
    if (!_isRecordingVoiceNote) return;
    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (_) {}

    final path = (recordedPath ?? _recordingVoiceNotePath ?? '').trim();
    if (mounted) {
      setState(() {
        _isRecordingVoiceNote = false;
        _recordingVoiceNoteSubmissionId = null;
        _recordingVoiceNotePath = null;
      });
    } else {
      _isRecordingVoiceNote = false;
      _recordingVoiceNoteSubmissionId = null;
      _recordingVoiceNotePath = null;
    }

    if (path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<bool> _stopVoiceNoteRecording(FormCheckSubmission item) async {
    final submissionId = item.submissionId;
    if (!_isRecordingVoiceNote ||
        _recordingVoiceNoteSubmissionId != submissionId) {
      return false;
    }

    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (_) {
      _showSnack('Could not finish voice recording.');
      return false;
    }

    final audioPath = (recordedPath ?? _recordingVoiceNotePath ?? '').trim();
    if (mounted) {
      setState(() {
        _isRecordingVoiceNote = false;
        _recordingVoiceNoteSubmissionId = null;
        _recordingVoiceNotePath = null;
      });
    } else {
      _isRecordingVoiceNote = false;
      _recordingVoiceNoteSubmissionId = null;
      _recordingVoiceNotePath = null;
    }
    if (audioPath.isEmpty) {
      _showSnack('No voice note was recorded.');
      return false;
    }

    if (mounted) {
      setState(() {
        _pendingVoiceNoteSubmissionId = submissionId;
        _pendingVoiceNotePath = audioPath;
      });
    } else {
      _pendingVoiceNoteSubmissionId = submissionId;
      _pendingVoiceNotePath = audioPath;
    }
    _showSnack('Recording stopped. Send or cancel.');
    return true;
  }

  Future<FormCheckSubmission?> _sendPendingVoiceNote(
    FormCheckSubmission item,
  ) async {
    final submissionId = item.submissionId;
    if (_sendingVoiceNoteIds.contains(submissionId)) return null;
    if (!_hasPendingVoiceNoteForSubmission(submissionId)) return null;

    final audioPath = (_pendingVoiceNotePath ?? '').trim();
    if (audioPath.isEmpty) {
      _showSnack('No voice note was recorded.');
      return null;
    }

    final controller = _reviewControllerFor(item);
    final optionalText = controller.text.trim();

    setState(() => _sendingVoiceNoteIds.add(submissionId));
    try {
      final updated = await ProgressionReviewService.submitFormCheckVoiceNote(
        submissionId: submissionId,
        audioFilePath: audioPath,
        reviewText: optionalText.isEmpty ? null : optionalText,
      );
      if (!mounted) return null;
      setState(() {
        _replaceFormCheckItem(updated);
      });
      if (optionalText.isNotEmpty) {
        controller.clear();
      }
      await _clearPendingVoiceNote(
        submissionId: submissionId,
        deleteFile: true,
      );
      _showSnack('Voice note sent.');
      return updated;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _sendingVoiceNoteIds.remove(submissionId));
      }
    }
  }

  Future<FormCheckSubmission?> _handlePrimarySend(
    FormCheckSubmission item,
  ) async {
    final submissionId = item.submissionId;
    if (_savingReviewIds.contains(submissionId) ||
        _sendingVoiceNoteIds.contains(submissionId)) {
      return null;
    }

    if (_isRecordingVoiceNote) {
      _showSnack('Stop recording before sending.');
      return null;
    }

    if (_hasPendingVoiceNoteForSubmission(submissionId)) {
      return _sendPendingVoiceNote(item);
    }

    return _saveWrittenReview(item);
  }

  Future<FormCheckSubmission?> _toggleReplyPinned({
    required FormCheckSubmission item,
    required FormCheckCoachReply reply,
  }) async {
    final replyId = reply.replyId;
    if (_pinningReplyIds.contains(replyId)) return null;

    setState(() => _pinningReplyIds.add(replyId));
    try {
      final updated = await ProgressionReviewService.setFormCheckReplyPinned(
        submissionId: item.submissionId,
        replyId: replyId,
        isPinned: !reply.isPinned,
      );
      if (!mounted) return null;
      setState(() {
        _replaceFormCheckItem(updated);
      });
      _showSnack(reply.isPinned ? 'Reply unpinned.' : 'Reply pinned.');
      return updated;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _pinningReplyIds.remove(replyId));
      }
    }
  }

  Future<FormCheckSubmission?> _toggleReviewPinned({
    required FormCheckSubmission item,
  }) async {
    final review = item.coachReview;
    if (review == null) return null;
    final submissionId = item.submissionId;
    if (_pinningReviewIds.contains(submissionId)) return null;

    setState(() => _pinningReviewIds.add(submissionId));
    try {
      final updated = await ProgressionReviewService.setFormCheckReviewPinned(
        submissionId: submissionId,
        isPinned: !review.isPinned,
      );
      if (!mounted) return null;
      setState(() {
        _replaceFormCheckItem(updated);
      });
      _showSnack(
        review.isPinned ? 'Voice note unpinned.' : 'Voice note pinned.',
      );
      return updated;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      if (mounted) {
        setState(() => _pinningReviewIds.remove(submissionId));
      }
    }
  }

  FormCheckSubmission _submissionById(int submissionId) {
    for (final item in _sharedFormChecks) {
      if (item.submissionId == submissionId) return item;
    }
    return _sharedFormChecks.firstWhere(
      (item) => item.submissionId == submissionId,
    );
  }

  List<FormCheckCoachReply> _sortedRepliesForHistory(
    List<FormCheckCoachReply> replies,
  ) {
    final sorted = List<FormCheckCoachReply>.from(replies);
    sorted.sort((a, b) {
      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated != null && bCreated != null) {
        final byCreated = aCreated.compareTo(bCreated);
        if (byCreated != 0) return byCreated;
      } else if (aCreated == null && bCreated != null) {
        return 1;
      } else if (aCreated != null && bCreated == null) {
        return -1;
      }
      return a.replyId.compareTo(b.replyId);
    });
    return sorted;
  }

  Future<void> _openSubmissionReviewSheet(FormCheckSubmission item) async {
    final controller = _reviewControllerFor(item);
    var current = item;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _activeReviewSheetSetState = setSheetState;
            final submissionId = current.submissionId;
            final isSaving = _savingReviewIds.contains(submissionId);
            final isSendingVoice = _sendingVoiceNoteIds.contains(submissionId);
            final isPinningReview = _pinningReviewIds.contains(submissionId);
            final isRecordingVoice =
                _isRecordingVoiceNote &&
                _recordingVoiceNoteSubmissionId == submissionId;
            final hasPendingVoice = _hasPendingVoiceNoteForSubmission(
              submissionId,
            );
            final pendingVoicePath = hasPendingVoice
                ? (_pendingVoiceNotePath ?? '').trim()
                : '';
            final pendingVoiceKey = pendingVoicePath.isEmpty
                ? ''
                : _pendingVoiceSourceKey(pendingVoicePath);
            final isPendingVoiceLoading =
                pendingVoiceKey.isNotEmpty &&
                _isVoiceNoteLoading(pendingVoiceKey);
            final isPendingVoicePlaying =
                pendingVoiceKey.isNotEmpty &&
                _isVoiceNotePlaying(pendingVoiceKey);
            final replies = _sortedRepliesForHistory(
              current.coachReviewReplies,
            );
            final voiceNoteUrl = _normalizeVoiceNoteUrl(
              current.coachReview?.voiceNoteUrl,
            );
            final reviewSeenAt = current.coachReview?.clientSeenAt;
            final isVoicePlaying = _isVoiceNotePlaying(voiceNoteUrl);
            final isVoiceLoading = _isVoiceNoteLoading(voiceNoteUrl);
            final isReviewPinned = current.coachReview?.isPinned == true;
            final aiSummary = (current.result.feedbackSummary ?? '').trim();
            final aiBullets = current.result.feedbackBullets;
            final aiIssues = current.result.detectedIssues;
            final hasAiAnalysis =
                aiSummary.isNotEmpty ||
                aiBullets.isNotEmpty ||
                aiIssues.isNotEmpty;

            Future<void> handleSend() async {
              final updated = await _handlePrimarySend(current);
              if (updated == null || !mounted) return;
              current = _submissionById(updated.submissionId);
              setSheetState(() {});
            }

            Future<void> handleRecordToggle() async {
              if (isRecordingVoice) {
                final stopped = await _stopVoiceNoteRecording(current);
                if (!stopped || !mounted) return;
                setSheetState(() {});
                return;
              }
              final started = await _startVoiceNoteRecording(current);
              if (!started || !mounted) return;
              setSheetState(() {});
            }

            Future<void> handlePendingVoiceCancel() async {
              await _clearPendingVoiceNote(
                submissionId: submissionId,
                deleteFile: true,
              );
              if (!mounted) return;
              setSheetState(() {});
            }

            Future<void> handleVoicePlayback() async {
              await _toggleVoiceNotePlayback(voiceNoteUrl);
              if (!mounted) return;
              setSheetState(() {});
            }

            Future<void> handleReviewPinToggle() async {
              final updated = await _toggleReviewPinned(item: current);
              if (updated == null || !mounted) return;
              current = _submissionById(updated.submissionId);
              setSheetState(() {});
            }

            Future<void> handlePinToggle(FormCheckCoachReply reply) async {
              final updated = await _toggleReplyPinned(
                item: current,
                reply: reply,
              );
              if (updated == null || !mounted) return;
              current = _submissionById(updated.submissionId);
              setSheetState(() {});
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.video_collection_outlined,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            current.exerciseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            if (isRecordingVoice) {
                              await _cancelVoiceNoteRecording();
                            }
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    Text(
                      'Shared: ${_formatDateTime(current.sharedAt ?? current.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openVideoInApp(
                            current.originalVideoUrl,
                            title: current.exerciseName,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open video'),
                        ),
                        if ((current.result.overlayUrl ?? '').trim().isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _openVideoInApp(
                              current.result.overlayUrl,
                              title: '${current.exerciseName} (Overlay)',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: const Icon(Icons.insights_outlined, size: 16),
                            label: const Text('Open overlay'),
                          ),
                      ],
                    ),
                    if (hasAiAnalysis) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Taqa Agent analysis',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (aiSummary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                aiSummary,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                            if (aiBullets.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...aiBullets.map(
                                (bullet) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          bullet,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (aiIssues.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Detected focus areas: ${aiIssues.join(', ')}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else if (current.isProcessing) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Taqa Agent analysis is still processing.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write review notes for the client...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed:
                              (isSaving ||
                                  isSendingVoice ||
                                  _isRecordingVoiceNote)
                              ? null
                              : handleSend,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, size: 14),
                          label: Text(isSaving ? 'Sending...' : 'Send'),
                        ),
                        const SizedBox(width: 8),
                        if (isRecordingVoice)
                          OutlinedButton.icon(
                            onPressed: (isSaving || isSendingVoice)
                                ? null
                                : handleRecordToggle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: const Icon(Icons.stop, size: 14),
                            label: const Text('Stop'),
                          )
                        else if (hasPendingVoice) ...[
                          TextButton.icon(
                            onPressed:
                                (isSaving ||
                                    isSendingVoice ||
                                    pendingVoicePath.isEmpty)
                                ? null
                                : () => _togglePendingVoiceNotePlayback(
                                    pendingVoicePath,
                                  ),
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
                            icon: isPendingVoiceLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : Icon(
                                    isPendingVoicePlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 16,
                                  ),
                            label: Text(
                              isPendingVoicePlaying
                                  ? 'Pause preview'
                                  : 'Play preview',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: (isSaving || isSendingVoice)
                                ? null
                                : handlePendingVoiceCancel,
                            child: const Text('Cancel'),
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: (isSaving || isSendingVoice)
                                ? null
                                : handleRecordToggle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: const Icon(Icons.mic, size: 14),
                            label: const Text('Record voice'),
                          ),
                      ],
                    ),
                    if (isRecordingVoice) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(
                            Icons.fiber_manual_record,
                            size: 10,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          _AudioWaveBars(
                            color: Colors.redAccent,
                            barCount: 6,
                            minHeight: 4,
                            maxHeight: 14,
                            barWidth: 3,
                            gap: 2,
                          ),
                        ],
                      ),
                    ],
                    if (replies.isEmpty &&
                        voiceNoteUrl.isEmpty &&
                        current.coachReview != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          reviewSeenAt == null
                              ? 'Unseen by client'
                              : 'Seen by client',
                          style: TextStyle(
                            color: reviewSeenAt == null
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (replies.isEmpty && voiceNoteUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Voice note: ${_formatDateTime(current.coachReview?.updatedAt ?? current.coachReview?.reviewedAt)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  reviewSeenAt == null ? 'Unseen' : 'Seen',
                                  style: TextStyle(
                                    color: reviewSeenAt == null
                                        ? Colors.orangeAccent
                                        : Colors.greenAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: isVoiceLoading
                                          ? null
                                          : handleVoicePlayback,
                                      icon: isVoiceLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white70,
                                              ),
                                            )
                                          : Icon(
                                              isVoicePlaying
                                                  ? Icons.pause_circle_filled
                                                  : Icons.play_circle_fill,
                                              color: Colors.white,
                                            ),
                                      tooltip: isVoicePlaying
                                          ? 'Pause'
                                          : 'Play',
                                    ),
                                    const SizedBox(width: 4),
                                    OutlinedButton.icon(
                                      onPressed: isPinningReview
                                          ? null
                                          : handleReviewPinToggle,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isReviewPinned
                                            ? Colors.orangeAccent
                                            : Colors.white70,
                                        side: BorderSide(
                                          color: isReviewPinned
                                              ? Colors.orangeAccent
                                              : Colors.white24,
                                        ),
                                        minimumSize: const Size(0, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: const VisualDensity(
                                          horizontal: -2,
                                          vertical: -2,
                                        ),
                                      ),
                                      icon: isPinningReview
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white70,
                                              ),
                                            )
                                          : Icon(
                                              isReviewPinned
                                                  ? Icons.push_pin
                                                  : Icons.push_pin_outlined,
                                              size: 12,
                                            ),
                                      label: Text(
                                        isReviewPinned ? 'Unpin' : 'Pin',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isReviewPinned) ...[
                        const SizedBox(height: 6),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Pinned correction',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Reply History',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (replies.isEmpty)
                      const Text(
                        'No replies yet.',
                        style: TextStyle(color: Colors.white54),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: replies.length,
                          itemBuilder: (context, index) {
                            final reply = replies[replies.length - 1 - index];
                            final replyVoiceNoteUrl = _normalizeVoiceNoteUrl(
                              reply.voiceNoteUrl,
                            );
                            final hasReplyVoiceNote =
                                replyVoiceNoteUrl.isNotEmpty;
                            final isReplyVoiceLoading =
                                hasReplyVoiceNote &&
                                _isVoiceNoteLoading(replyVoiceNoteUrl);
                            final isReplyVoicePlaying =
                                hasReplyVoiceNote &&
                                _isVoiceNotePlaying(replyVoiceNoteUrl);
                            final replyText = reply.replyText.trim();
                            final replyMessage = replyText.isNotEmpty
                                ? replyText
                                : (hasReplyVoiceNote
                                      ? 'Voice note from coach.'
                                      : '');
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDateTime(
                                            reply.createdAt ?? reply.updatedAt,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _pinningReplyIds.contains(
                                              reply.replyId,
                                            )
                                            ? null
                                            : () => handlePinToggle(reply),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: reply.isPinned
                                              ? Colors.orangeAccent
                                              : Colors.white70,
                                          side: BorderSide(
                                            color: reply.isPinned
                                                ? Colors.orangeAccent
                                                : Colors.white24,
                                          ),
                                          minimumSize: const Size(0, 26),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: const VisualDensity(
                                            horizontal: -2,
                                            vertical: -2,
                                          ),
                                        ),
                                        icon:
                                            _pinningReplyIds.contains(
                                              reply.replyId,
                                            )
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white70,
                                                    ),
                                              )
                                            : Icon(
                                                reply.isPinned
                                                    ? Icons.push_pin
                                                    : Icons.push_pin_outlined,
                                                size: 12,
                                              ),
                                        label: Text(
                                          reply.isPinned ? 'Unpin' : 'Pin',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (replyMessage.isNotEmpty)
                                    Text(
                                      replyMessage,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  if (hasReplyVoiceNote) ...[
                                    if (replyMessage.isNotEmpty)
                                      const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: isReplyVoiceLoading
                                              ? null
                                              : () => _toggleVoiceNotePlayback(
                                                  replyVoiceNoteUrl,
                                                ),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(0, 26),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            visualDensity: const VisualDensity(
                                              horizontal: -2,
                                              vertical: -3,
                                            ),
                                          ),
                                          icon: isReplyVoiceLoading
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white70,
                                                      ),
                                                )
                                              : Icon(
                                                  isReplyVoicePlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            isReplyVoicePlaying
                                                ? 'Pause'
                                                : 'Play',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    reply.clientSeenAt == null
                                        ? 'Unseen by client'
                                        : 'Seen by client',
                                    style: TextStyle(
                                      color: reply.clientSeenAt == null
                                          ? Colors.orangeAccent
                                          : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    _activeReviewSheetSetState = null;
    try {
      await _voicePlayer.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _activeVoiceNoteUrl = null;
        _loadingVoiceNoteUrl = null;
      });
    } else {
      _activeVoiceNoteUrl = null;
      _loadingVoiceNoteUrl = null;
    }
    if (_isRecordingVoiceNote &&
        _recordingVoiceNoteSubmissionId == item.submissionId) {
      await _cancelVoiceNoteRecording();
    }
    if (_pendingVoiceNoteSubmissionId == item.submissionId) {
      await _clearPendingVoiceNote(
        submissionId: item.submissionId,
        deleteFile: true,
      );
    }
  }

  Future<void> _openHabitsPage() async {
    final name = _displayName();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientHabitsPage(
          clientId: widget.client.userId,
          clientName: name,
          avatarUrl: _resolvedAvatarUrl(),
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAnalyticsPage() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, animation, secondaryAnimation) =>
            ExpertClientAnalyticsPage(
              client: widget.client,
              reviews: widget.reviews,
              onTrainingPlanVerified: _handleTrainingPlanVerified,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openDietReviewPage() async {
    if (_showDietLogPendingNote && mounted) {
      setState(() {
        _showDietLogPendingNote = false;
      });
    }
    if (!_dietLogSeenNotified) {
      _dietLogSeenNotified = true;
      widget.onDietLogSeen?.call();
    }
    unawaited(
      ProgressionReviewService.markClientDietLogSeen(
        clientUserId: widget.client.userId,
      ).catchError((_) {}),
    );
    final clientName = _displayName();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientDietReviewPage(
          clientUserId: widget.client.userId,
          clientName: clientName,
        ),
      ),
    );
  }

  Future<void> _openSupportChatPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientChatPage(
          clientUserId: widget.client.userId,
          clientName: _displayName(),
        ),
      ),
    );
    await _refreshSupportChatUnreadStatus();
  }

  Widget _buildClientOverviewCard() {
    final name = _displayName();
    final avatarUrl = (_resolvedAvatarUrl() ?? '').trim();
    final profile = _profile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white10,
                foregroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'User ID: ${widget.client.userId}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (_hasAiUpdatesPending) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _aiUpdatesStatusIcon,
                            size: 13,
                            color: _aiUpdatesStatusColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _aiUpdatesStatusText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _aiUpdatesStatusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _activityColor().withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _activityColor()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _activityColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activityLabel(),
                      style: TextStyle(
                        color: _activityColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (_profileError != null)
            Text(
              _profileError!,
              style: const TextStyle(color: Colors.orangeAccent),
            )
          else if (profile == null)
            const Text(
              'No profile data available.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Column(
              children: [
                _InfoRow(label: 'Age', value: _value(profile['age'])),
                const SizedBox(height: 6),
                _InfoRow(label: 'Sex', value: _value(profile['sex'])),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Height',
                  value: '${_value(profile['height_cm'])} cm',
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Weight',
                  value: '${_value(profile['weight_kg'])} kg',
                ),
                const SizedBox(height: 6),
                _InfoRow(label: 'Goal', value: _value(profile['fitness_goal'])),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Training days',
                  value: _value(profile['training_days']),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAnalyticsPage,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_showTrainingPlanPendingNote)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5FD8FF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFF5FD8FF,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Color(0xFF5FD8FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Open client analytics and activity status.',
                style: TextStyle(color: Colors.white70),
              ),
              if (_showTrainingPlanPendingNote) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 14,
                      color: Color(0xFF5FD8FF),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Client's plan not checked yet.",
                        style: TextStyle(
                          color: Color(0xFF5FD8FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openAnalyticsPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.insights_outlined, size: 16),
                  label: const Text('View Analytics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitsCard() {
    final totalHabits = _habits.length;
    final checkedCount = _habits.where((habit) => habit.isCompleted).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _expertId == null ? null : _openHabitsPage,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Habits',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              if (_habitsError != null)
                Text(
                  _habitsError!,
                  style: const TextStyle(color: Colors.white70),
                )
              else if (totalHabits == 0)
                const Text(
                  'No habits set yet.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Column(
                  children: [
                    _InfoRow(label: 'Total habits', value: '$totalHabits'),
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: 'Checked this week',
                      value: '$checkedCount',
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _expertId == null ? null : _openHabitsPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Habits'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDietReviewCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openDietReviewPage,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Diet Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_showDietLogPendingNote)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5FD8FF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFF5FD8FF,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        widget.client.sharedDietLogCount > 1
                            ? 'New (${widget.client.sharedDietLogCount})'
                            : 'New',
                        style: const TextStyle(
                          color: Color(0xFF5FD8FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'View this client diet logs by date and leave coach comments.',
                style: TextStyle(color: Colors.white70),
              ),
              if (_showDietLogPendingNote) ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 14,
                      color: Color(0xFF5FD8FF),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'New diet logs available.',
                        style: TextStyle(
                          color: Color(0xFF5FD8FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openDietReviewPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.restaurant_outlined, size: 16),
                  label: const Text('Open Diet Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportChatCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSupportChatPage,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Support Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_supportChatHasUnread) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5FD8FF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFF5FD8FF,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Color(0xFF5FD8FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _supportChatHasUnread
                    ? 'Client sent a new message. Open support chat to read it.'
                    : 'Open chat thread with this client and send text replies.',
                style: TextStyle(
                  color: _supportChatHasUnread
                      ? const Color(0xFF5FD8FF)
                      : Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openSupportChatPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Open Chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormReviewCard() {
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
            'Form Review',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Only videos explicitly shared by this client are shown.',
            style: TextStyle(color: Colors.white70),
          ),
          if (_showFormReviewPendingNote) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.notification_important_outlined,
                  size: 14,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.client.sharedFormCheckCount > 1
                        ? 'Awaiting your reply (${widget.client.sharedFormCheckCount})'
                        : 'Awaiting your reply',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (_formChecksError != null)
            Text(
              _formChecksError!,
              style: const TextStyle(color: Colors.white70),
            )
          else if (_sharedFormChecks.isEmpty)
            const Text(
              'No videos available for review.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._sharedFormChecks.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openSubmissionReviewSheet(item),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.exerciseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (item.result.feedbackBullets.isNotEmpty ||
                            (item.result.feedbackSummary ?? '')
                                .trim()
                                .isNotEmpty)
                          const Text(
                            'Taqa Agent analysis ready',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          )
                        else if (item.isProcessing)
                          const Text(
                            'Taqa Agent analysis processing',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Tap to open',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAiUpdatesCard() {
    final statusColor = _aiUpdatesStatusColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAiUpdatesPage,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AI Updates',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_hasAiUpdatesPending)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _pendingAiUpdateCount > 1 ? 'New' : 'Pending',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Open AI-driven form feedback and training suggestions.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(_aiUpdatesStatusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aiUpdatesStatusText(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openAiUpdatesPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('Open AI Updates'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildClientOverviewCard(),
        const SizedBox(height: 12),
        _buildSupportChatCard(),
        const SizedBox(height: 12),
        _buildAnalyticsCard(),
        const SizedBox(height: 12),
        _buildHabitsCard(),
        const SizedBox(height: 12),
        _buildDietReviewCard(),
        const SizedBox(height: 12),
        _buildAiUpdatesCard(),
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Client View'),
        actions: [
          IconButton(
            onPressed: (_loading || _detachingClient || _reportingClient)
                ? null
                : _reportClient,
            icon: _reportingClient
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_outlined),
            tooltip: 'Report client',
            color: Colors.orangeAccent,
          ),
          IconButton(
            onPressed: (_loading || _detachingClient || _reportingClient)
                ? null
                : _detachClient,
            icon: _detachingClient
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_alt_1_outlined),
            tooltip: 'Detach client',
            color: Colors.redAccent,
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(onRefresh: _load, child: list),
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

class ExpertClientAiUpdatesPage extends StatefulWidget {
  const ExpertClientAiUpdatesPage({
    super.key,
    required this.client,
    required this.onOpenFormCheck,
  });

  final ProgressionClient client;
  final Future<void> Function(FormCheckSubmission item) onOpenFormCheck;

  @override
  State<ExpertClientAiUpdatesPage> createState() =>
      _ExpertClientAiUpdatesPageState();
}

class _ExpertClientAiUpdatesPageState extends State<ExpertClientAiUpdatesPage> {
  bool _loading = true;
  bool _generatingAiReview = false;
  bool _showFormReviewPendingNote = false;
  bool _showTrainingPlanPendingNote = false;
  String? _formChecksError;
  List<FormCheckSubmission> _sharedFormChecks = const [];
  List<ProgressionReview> _clientReviews = const [];

  @override
  void initState() {
    super.initState();
    _showFormReviewPendingNote = widget.client.hasFormCheckToReview;
    _showTrainingPlanPendingNote = widget.client.hasUncheckedTrainingPlan;
    _load();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _formChecksError = null;
      });
    }

    String? formChecksError;
    List<FormCheckSubmission> sharedFormChecks = const [];
    List<ProgressionReview> clientReviews = const [];
    bool showTrainingPlanPendingNote = _showTrainingPlanPendingNote;

    try {
      final status =
          await ProgressionReviewService.fetchClientTrainingPlanSeenStatus(
            clientUserId: widget.client.userId,
          );
      showTrainingPlanPendingNote =
          status['has_unchecked_training_plan'] == true;
    } catch (_) {}

    try {
      sharedFormChecks =
          await ProgressionReviewService.fetchClientSharedFormChecks(
            widget.client.userId,
          );
    } catch (e) {
      formChecksError = _normalizeError(e);
    }

    try {
      final reviews = await ProgressionReviewService.fetchReviews(
        includeApplied: true,
      );
      clientReviews = reviews
          .where((r) => r.userId == widget.client.userId)
          .toList();
      clientReviews.sort((a, b) {
        final aPriority = a.isPendingExpert
            ? 0
            : a.isReviewed
            ? 1
            : a.isApplied
            ? 2
            : 3;
        final bPriority = b.isPendingExpert
            ? 0
            : b.isReviewed
            ? 1
            : b.isApplied
            ? 2
            : 3;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        final aDate = a.reviewedAt ?? a.appliedAt ?? a.weekStart ?? '';
        final bDate = b.reviewedAt ?? b.appliedAt ?? b.weekStart ?? '';
        return bDate.compareTo(aDate);
      });
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _sharedFormChecks = sharedFormChecks;
      _clientReviews = clientReviews;
      _formChecksError = formChecksError;
      _showFormReviewPendingNote = sharedFormChecks.any(
        (item) => item.coachReview == null,
      );
      _showTrainingPlanPendingNote = showTrainingPlanPendingNote;
      _loading = false;
    });
  }

  String _normalizeError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw.isEmpty ? 'Unavailable' : raw;
  }

  int get _pendingAiUpdateCount {
    var count = 0;
    if (_showFormReviewPendingNote) {
      final pendingFormCount = _sharedFormChecks
          .where((item) => item.coachReview == null)
          .length;
      count += math.max(pendingFormCount, 1);
    }
    if (_showTrainingPlanPendingNote) {
      count += math.max(widget.client.trainingPlanUncheckedCount, 1);
    }
    return count;
  }

  IconData get _aiUpdatesStatusIcon {
    if (_showFormReviewPendingNote) {
      return Icons.notification_important_outlined;
    }
    return Icons.auto_awesome_rounded;
  }

  Color get _aiUpdatesStatusColor {
    if (_showFormReviewPendingNote) {
      return Colors.orangeAccent;
    }
    return const Color(0xFF5FD8FF);
  }

  String _aiUpdatesStatusText() {
    final hasForm = _showFormReviewPendingNote;
    final hasTraining = _showTrainingPlanPendingNote;
    if (hasForm && hasTraining) {
      final count = _pendingAiUpdateCount;
      return count > 1
          ? 'AI updates pending review ($count)'
          : 'AI update pending review';
    }
    if (hasForm) {
      final pendingFormCount = _sharedFormChecks
          .where((item) => item.coachReview == null)
          .length;
      return pendingFormCount > 1
          ? 'Form checks awaiting reply ($pendingFormCount)'
          : 'Form check awaiting reply';
    }
    if (hasTraining) {
      return widget.client.trainingPlanUncheckedCount > 1
          ? 'Training suggestions pending review (${widget.client.trainingPlanUncheckedCount})'
          : 'Training suggestions pending review';
    }
    return _clientReviews.isNotEmpty
        ? 'Latest AI updates ready'
        : 'No AI updates pending';
  }

  Future<void> _generateAiReview({required bool force}) async {
    if (_generatingAiReview) return;
    setState(() => _generatingAiReview = true);
    try {
      final result = await ProgressionReviewService.generateReview(
        widget.client.userId,
        force: force,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString();
      String message;
      switch (status) {
        case 'generated':
          message = 'AI update review generated.';
          break;
        case 'exists':
          message = 'A review already exists for this week.';
          break;
        case 'noop':
          message = _aiUpdateGenerationMessage(result);
          break;
        case 'failed':
          message =
              (result['detail'] ?? result['reason'] ?? 'Generation failed.')
                  .toString();
          break;
        default:
          message = (result['detail'] ?? 'AI update request completed.')
              .toString();
          break;
      }
      _showSnack(message);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _generatingAiReview = false);
      }
    }
  }

  Future<void> _openAiReview(ProgressionReview review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertProgressionReviewPage(reviewId: review.reviewId),
      ),
    );
    await _load();
  }

  Future<void> _openFormCheck(FormCheckSubmission item) async {
    await widget.onOpenFormCheck(item);
    await _load();
  }

  Widget _buildFormCheckTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Only videos explicitly shared by this client are shown.',
          style: TextStyle(color: Colors.white70),
        ),
        if (_showFormReviewPendingNote) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.notification_important_outlined,
                size: 14,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sharedFormChecks
                              .where((item) => item.coachReview == null)
                              .length >
                          1
                      ? 'Awaiting your reply (${_sharedFormChecks.where((item) => item.coachReview == null).length})'
                      : 'Awaiting your reply',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (_formChecksError != null)
          Text(_formChecksError!, style: const TextStyle(color: Colors.white70))
        else if (_sharedFormChecks.isEmpty)
          const Text(
            'No videos available for review.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ..._sharedFormChecks.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openFormCheck(item),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.exerciseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AiUpdateStatusPill(
                            label: item.coachReview == null
                                ? 'Pending reply'
                                : 'Reviewed',
                            color: item.coachReview == null
                                ? Colors.orangeAccent
                                : const Color(0xFF4ADE80),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ((item.result.feedbackSummary ?? '').trim().isNotEmpty)
                            ? item.result.feedbackSummary!.trim()
                            : 'Open to review this form check.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTrainingSuggestionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'AI-generated progression reviews for this client.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _generatingAiReview
                  ? null
                  : () => _generateAiReview(force: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
              ),
              child: Text(_generatingAiReview ? 'Working...' : 'Generate'),
            ),
          ],
        ),
        if (_showTrainingPlanPendingNote) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Color(0xFF5FD8FF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.client.trainingPlanUncheckedCount > 1
                      ? 'Training suggestions pending review (${widget.client.trainingPlanUncheckedCount})'
                      : 'Training suggestions pending review',
                  style: const TextStyle(
                    color: Color(0xFF5FD8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (_clientReviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No AI training suggestions yet. Generate one for this client from here.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ..._clientReviews.map(
            (review) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClientAiReviewCard(
                review: review,
                onTap: () => _openAiReview(review),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: const Text('AI Updates'),
          bottom: const TabBar(
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Form Check'),
              Tab(text: 'Training Suggestions'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _aiUpdatesStatusIcon,
                          size: 16,
                          color: _aiUpdatesStatusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiUpdatesStatusText(),
                            style: TextStyle(
                              color: _aiUpdatesStatusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildFormCheckTab(),
                        _buildTrainingSuggestionsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AiUpdateStatusPill extends StatelessWidget {
  const _AiUpdateStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ClientAiReviewCard extends StatelessWidget {
  const _ClientAiReviewCard({required this.review, required this.onTap});

  final ProgressionReview review;
  final VoidCallback onTap;

  Color _statusColor() {
    switch (review.status) {
      case 'applied':
        return AppColors.successGreen;
      case 'failed':
        return AppColors.errorRed;
      case 'pending_expert':
        return const Color(0xFF5FD8FF);
      case 'reviewed':
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }

  String _statusLabel() {
    switch (review.status) {
      case 'pending_expert':
        return 'Pending review';
      case 'reviewed':
        return 'Awaiting approval';
      case 'applied':
        return 'Applied';
      case 'failed':
        return 'Needs retry';
      default:
        return review.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${review.weekStart ?? '-'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${review.itemCount} suggestions',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  if ((review.aiSummary ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      review.aiSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AiUpdateStatusPill(label: _statusLabel(), color: statusColor),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
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
