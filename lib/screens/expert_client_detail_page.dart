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
import '../core/user_friendly_error.dart';
import '../services/auth/profile_service.dart';
import '../services/coach/chat_attachment_file_service.dart';
import '../services/coach/coach_habits_service.dart';
import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/form_check_service.dart';
import '../services/coach/progression_review_service.dart';
import '../services/coach/voice_note_audio_service.dart';
import 'expert_client_analytics_page.dart';
import 'expert_client_chat_page.dart';
import 'expert_client_diet_review_page.dart';
import 'expert_client_habits_page.dart';
import 'expert_progression_review_page.dart';
import 'expert_training_plan_review_page.dart';
import '../widgets/coach/chat_video_player_page.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_comment_composer_page.dart';
import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_expert_client_view.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_pill_tab.dart';
import '../TaqaUI/components/taqa_profile_info_section.dart';
import '../TaqaUI/components/taqa_stop_sign_icon.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/components/taqa_person_remove_icon.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

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

AppToastType _clientToastType(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('failed') ||
      normalized.contains('error') ||
      normalized.contains('could not') ||
      normalized.contains('required')) {
    return AppToastType.error;
  }
  if (normalized.contains('sent') ||
      normalized.contains('submitted') ||
      normalized.contains('saved') ||
      normalized.contains('pinned') ||
      normalized.contains('stopped')) {
    return AppToastType.success;
  }
  return AppToastType.info;
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
  String? _activityStatus;
  int? _inactiveDays;
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
  bool _detachingClient = false;
  bool _reportingClient = false;
  late bool _showFormReviewPendingNote;
  late bool _showDietLogPendingNote;
  late bool _showTrainingPlanPendingNote;
  bool _dietLogSeenNotified = false;
  bool _supportChatHasUnread = false;
  bool _openingTrainingPlan = false;

  @override
  void initState() {
    super.initState();
    _clientReviews = widget.reviews
        .where((review) => review.userId == widget.client.userId)
        .toList();
    _showFormReviewPendingNote = widget.client.hasFormCheckToReview;
    _showDietLogPendingNote = widget.client.hasDietLogToReview;
    _showTrainingPlanPendingNote = widget.client.hasUncheckedTrainingPlan;
    _activityStatus = widget.client.activityStatus;
    _inactiveDays = widget.client.inactiveDays;
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
      });
    }

    Map<String, dynamic>? profile;
    List<CoachHabitItem> habits = const [];
    List<FormCheckSubmission> sharedFormChecks = const [];
    int? expertId;
    String? profileError;
    String? habitsError;
    bool showTrainingPlanPendingNote = _showTrainingPlanPendingNote;
    bool supportChatHasUnread = _supportChatHasUnread;
    String? activityStatus = _activityStatus ?? widget.client.activityStatus;
    int? inactiveDays = _inactiveDays ?? widget.client.inactiveDays;

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
      profile = await ProfileApi.fetchCoachClientProfile(widget.client.userId);
    } catch (e) {
      profileError = _normalizeProfileError(e);
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
    } catch (_) {}

    try {
      supportChatHasUnread =
          await CoachSupportChatService.fetchCoachClientThreadHasUnread(
            clientUserId: widget.client.userId,
          );
    } catch (_) {
      // Keep previous value if support-chat status cannot be loaded.
    }

    try {
      final analytics = await ProgressionReviewService.fetchClientAnalytics(
        widget.client.userId,
      );
      final rawActivity = analytics['activity'];
      if (rawActivity is Map) {
        final activityMap = Map<String, dynamic>.from(rawActivity);
        final statusRaw = (activityMap['activity_status'] ?? '')
            .toString()
            .trim();
        if (statusRaw.isNotEmpty) {
          activityStatus = statusRaw;
        }
        inactiveDays =
            _parseNullableInt(activityMap['inactive_days']) ?? inactiveDays;
      }
    } catch (_) {
      // Keep previous status if analytics cannot be loaded.
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
      _showTrainingPlanPendingNote = showTrainingPlanPendingNote;
      _supportChatHasUnread = supportChatHasUnread;
      _activityStatus = activityStatus;
      _inactiveDays = inactiveDays;
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
          ? 'Training plans pending verification (${widget.client.trainingPlanUncheckedCount})'
          : 'Training plan pending verification';
    }
    final reviewCount = _clientAiReviews().length;
    return reviewCount > 0
        ? 'Latest AI updates ready'
        : 'No AI updates pending';
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

  String _normalizeProfileError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('forbidden') || raw.contains('403')) {
      return 'Profile information is unavailable.';
    }
    return userFriendlyErrorMessage(
      error,
      fallback: 'Profile information is unavailable.',
    );
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

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
    AppToast.show(context, message, type: _clientToastType(message));
  }

  Future<void> _detachClient() async {
    if (_detachingClient) return;
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: 'Detach client?',
      message:
          'Are you sure you want to detach this client from your coaching list?',
      confirmLabel: 'Detach',
      cancelLabel: 'Cancel',
    );
    if (!confirmed) return;

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
    final reason = await showTaqaMultilineTextDialog(
      context: context,
      title: 'Report client',
      message: 'Please write the reason for this report.',
      hintText: 'Write the reason...',
      confirmLabel: 'Report',
      requiredMessage: 'Reason is required.',
      maxLength: 1000,
    );
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

  Widget _reviewPillButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool loading = false,
    Color? activeColor,
  }) {
    final color = activeColor ?? TaqaUiColors.charcoal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(999),
        child: Container(
          height: TaqaUiScale.h(30),
          padding: TaqaUiScale.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(999),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: TaqaUiScale.w(12),
                  height: TaqaUiScale.w(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: TaqaUiScale.w(14), color: color),
              SizedBox(width: TaqaUiScale.w(6)),
              Text(
                label,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(11),
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSubmissionReviewSheet(FormCheckSubmission item) async {
    final controller = _reviewControllerFor(item);
    var current = item;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _activeReviewSheetSetState = setSheetState;
            final submissionId = current.submissionId;
            final isPinningReview = _pinningReviewIds.contains(submissionId);
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

            Future<void> openReplyComposer() async {
              if (_isRecordingVoiceNote ||
                  _hasPendingVoiceNoteForSubmission(submissionId)) {
                _showSnack('Finish or cancel the current voice note first.');
                return;
              }
              await Navigator.of(sheetContext).push<bool>(
                MaterialPageRoute(
                  builder: (_) => TaqaCommentComposerPage(
                    title: 'Reply to Client',
                    subject: current.exerciseName,
                    hintText: 'Write review notes for the client...',
                    onSubmit: (text) async {
                      controller.text = text;
                      await _saveWrittenReview(current);
                    },
                    onStartVoiceNote: () => _startVoiceNoteRecording(current),
                    onStopVoiceNote: () => _stopVoiceNoteRecording(current),
                    onSendVoiceNote: (text) async {
                      controller.text = text;
                      await _sendPendingVoiceNote(current);
                    },
                    onCancelVoiceNote: () => _clearPendingVoiceNote(
                      submissionId: submissionId,
                      deleteFile: true,
                    ),
                  ),
                ),
              );
              if (!mounted) return;
              current = _submissionById(submissionId);
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.video_collection_outlined,
                            color: TaqaUiColors.charcoal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              current.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                color: TaqaUiColors.charcoal,
                                fontWeight: FontWeight.w700,
                                fontSize: TaqaUiScale.sp(16),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: TaqaUiColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Shared: ${_formatDateTime(current.sharedAt ?? current.createdAt)}',
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                          fontSize: TaqaUiScale.sp(12),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(10)),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _reviewPillButton(
                            icon: Icons.open_in_new,
                            label: 'Open video',
                            onTap: () => _openVideoInApp(
                              current.originalVideoUrl,
                              title: current.exerciseName,
                            ),
                          ),
                          if ((current.result.overlayUrl ?? '')
                              .trim()
                              .isNotEmpty)
                            _reviewPillButton(
                              icon: Icons.insights_outlined,
                              label: 'Open overlay',
                              onTap: () => _openVideoInApp(
                                current.result.overlayUrl,
                                title: '${current.exerciseName} (Overlay)',
                              ),
                            ),
                        ],
                      ),
                      if (hasAiAnalysis) ...[
                        SizedBox(height: TaqaUiScale.h(12)),
                        TaqaClientDashboardCard(
                          padding: 12,
                          radius: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TaqaClientDashboardTitleText(
                                'Taqa Agent analysis',
                              ),
                              if (aiSummary.isNotEmpty) ...[
                                SizedBox(height: TaqaUiScale.h(8)),
                                TaqaClientDashboardBodyText(aiSummary),
                              ],
                              if (aiBullets.isNotEmpty) ...[
                                SizedBox(height: TaqaUiScale.h(10)),
                                ...aiBullets.map(
                                  (bullet) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: TaqaUiScale.h(6),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: TaqaUiScale.h(6),
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: TaqaUiScale.w(6),
                                            color: TaqaUiColors.charcoal
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        SizedBox(width: TaqaUiScale.w(8)),
                                        Expanded(
                                          child: TaqaClientDashboardBodyText(
                                            bullet,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (aiIssues.isNotEmpty) ...[
                                SizedBox(height: TaqaUiScale.h(6)),
                                Text(
                                  'Detected focus areas: ${aiIssues.join(', ')}',
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    color: TaqaUiColors.charcoal.withValues(
                                      alpha: 0.55,
                                    ),
                                    fontSize: TaqaUiScale.sp(12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (current.isProcessing) ...[
                        SizedBox(height: TaqaUiScale.h(12)),
                        Text(
                          'Taqa Agent analysis is still processing.',
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: TaqaUiScale.sp(12),
                          ),
                        ),
                      ],
                      SizedBox(height: TaqaUiScale.h(14)),
                      TaqaFilledButton(
                        label: current.coachReview == null
                            ? 'Write Reply'
                            : 'Add Reply',
                        onTap: openReplyComposer,
                        height: 45,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      if (replies.isEmpty &&
                          voiceNoteUrl.isEmpty &&
                          current.coachReview != null) ...[
                        SizedBox(height: TaqaUiScale.h(8)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            reviewSeenAt == null
                                ? 'Unseen by client'
                                : 'Seen by client',
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              color: reviewSeenAt == null
                                  ? TaqaUiColors.recordRed
                                  : const Color(0xFF2E8B57),
                              fontSize: TaqaUiScale.sp(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (replies.isEmpty && voiceNoteUrl.isNotEmpty) ...[
                        SizedBox(height: TaqaUiScale.h(10)),
                        TaqaClientDashboardCard(
                          padding: 10,
                          radius: 10,
                          child: Row(
                            children: [
                              Icon(
                                Icons.mic,
                                color: TaqaUiColors.charcoal.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              SizedBox(width: TaqaUiScale.w(8)),
                              Expanded(
                                child: TaqaClientDashboardBodyText(
                                  'Voice note: ${_formatDateTime(current.coachReview?.updatedAt ?? current.coachReview?.reviewedAt)}',
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    reviewSeenAt == null ? 'Unseen' : 'Seen',
                                    style: TextStyle(
                                      fontFamily:
                                          TaqaUiFontFamilies.interTight,
                                      color: reviewSeenAt == null
                                          ? TaqaUiColors.recordRed
                                          : const Color(0xFF2E8B57),
                                      fontSize: TaqaUiScale.sp(12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(2)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: isVoiceLoading
                                            ? null
                                            : handleVoicePlayback,
                                        icon: isVoiceLoading
                                            ? SizedBox(
                                                width: TaqaUiScale.w(16),
                                                height: TaqaUiScale.w(16),
                                                child:
                                                    const CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                isVoicePlaying
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_fill,
                                                color: TaqaUiColors.charcoal,
                                              ),
                                        tooltip: isVoicePlaying
                                            ? 'Pause'
                                            : 'Play',
                                      ),
                                      SizedBox(width: TaqaUiScale.w(4)),
                                      _reviewPillButton(
                                        icon: isReviewPinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        label: isReviewPinned
                                            ? 'Unpin'
                                            : 'Pin',
                                        onTap: isPinningReview
                                            ? null
                                            : handleReviewPinToggle,
                                        loading: isPinningReview,
                                        activeColor: isReviewPinned
                                            ? TaqaUiColors.recordRed
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isReviewPinned) ...[
                          SizedBox(height: TaqaUiScale.h(6)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Pinned correction',
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                color: TaqaUiColors.recordRed,
                                fontSize: TaqaUiScale.sp(11),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                      SizedBox(height: TaqaUiScale.h(12)),
                      const TaqaClientDashboardTitleText('Reply History'),
                      SizedBox(height: TaqaUiScale.h(8)),
                      if (replies.isEmpty)
                        const TaqaClientDashboardBodyText('No replies yet.')
                      else
                        ...replies.reversed.map((reply) {
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
                          final isPinningReply = _pinningReplyIds.contains(
                            reply.replyId,
                          );
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: TaqaUiScale.h(8),
                            ),
                            child: TaqaClientDashboardCard(
                              padding: 10,
                              radius: 10,
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
                                          style: TextStyle(
                                            fontFamily:
                                                TaqaUiFontFamilies.interTight,
                                            color: TaqaUiColors.charcoal
                                                .withValues(alpha: 0.55),
                                            fontSize: TaqaUiScale.sp(12),
                                          ),
                                        ),
                                      ),
                                      _reviewPillButton(
                                        icon: reply.isPinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        label: reply.isPinned
                                            ? 'Unpin'
                                            : 'Pin',
                                        onTap: isPinningReply
                                            ? null
                                            : () => handlePinToggle(reply),
                                        loading: isPinningReply,
                                        activeColor: reply.isPinned
                                            ? TaqaUiColors.recordRed
                                            : null,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: TaqaUiScale.h(4)),
                                  if (replyMessage.isNotEmpty)
                                    TaqaClientDashboardBodyText(replyMessage),
                                  if (hasReplyVoiceNote) ...[
                                    if (replyMessage.isNotEmpty)
                                      SizedBox(height: TaqaUiScale.h(4)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: isReplyVoiceLoading
                                              ? null
                                              : () async {
                                                  await _toggleVoiceNotePlayback(
                                                    replyVoiceNoteUrl,
                                                  );
                                                  if (!mounted) return;
                                                  setSheetState(() {});
                                                },
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                TaqaUiColors.charcoal,
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
                                  SizedBox(height: TaqaUiScale.h(4)),
                                  Text(
                                    reply.clientSeenAt == null
                                        ? 'Unseen by client'
                                        : 'Seen by client',
                                    style: TextStyle(
                                      fontFamily:
                                          TaqaUiFontFamilies.interTight,
                                      color: reply.clientSeenAt == null
                                          ? TaqaUiColors.recordRed
                                          : const Color(0xFF2E8B57),
                                      fontSize: TaqaUiScale.sp(12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
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
          clientActivityStatus: _activityStatus ?? widget.client.activityStatus,
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

  Future<void> _openTrainingPlanPage() async {
    if (_openingTrainingPlan) return;
    setState(() => _openingTrainingPlan = true);

    Map<String, dynamic> activeProgram = const {};
    String? trainingPlanError;
    try {
      activeProgram =
          await ProgressionReviewService.fetchClientActiveTrainingProgram(
            widget.client.userId,
          );
    } catch (e) {
      final normalized = _normalizeHabitsError(e);
      if (normalized.toLowerCase().contains(
            'failed to load client training program',
          ) ||
          normalized.toLowerCase().contains('no program found') ||
          normalized.toLowerCase().contains('404')) {
        trainingPlanError = 'No active training plan yet.';
      } else {
        trainingPlanError = normalized;
      }
      activeProgram = const {};
    }

    if (!mounted) return;
    setState(() => _openingTrainingPlan = false);

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ExpertTrainingPlanReviewPage(
          clientUserId: widget.client.userId,
          clientName: _displayName(),
          clientAvatarUrl: _resolvedAvatarUrl(),
          clientActivityStatus: _activityStatus ?? widget.client.activityStatus,
          activeProgram: activeProgram,
          trainingPlanError: trainingPlanError,
        ),
      ),
    );

    if (!mounted || result == null) return;
    if (result['didCheck'] == true) {
      _handleTrainingPlanVerified();
    }
    await _load();
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
          clientAvatarUrl: _resolvedAvatarUrl(),
          clientActivityStatus: _activityStatus ?? widget.client.activityStatus,
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
          clientAvatarUrl: _resolvedAvatarUrl(),
          clientActivityStatus: _activityStatus ?? widget.client.activityStatus,
        ),
      ),
    );
    await _refreshSupportChatUnreadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final personalInfoItems = _profileError != null
        ? [TaqaProfileInfoItem(label: 'Status', value: _profileError!)]
        : profile == null
        ? const [
            TaqaProfileInfoItem(
              label: 'Status',
              value: 'No profile data available.',
            ),
          ]
        : [
            TaqaProfileInfoItem(label: 'Age', value: _value(profile['age'])),
            TaqaProfileInfoItem(label: 'Sex', value: _value(profile['sex'])),
            TaqaProfileInfoItem(
              label: 'Height',
              value: '${_value(profile['height_cm'])} cm',
            ),
            TaqaProfileInfoItem(
              label: 'Weight',
              value: '${_value(profile['weight_kg'])} kg',
            ),
            TaqaProfileInfoItem(
              label: 'Occupation',
              value: _value(profile['occupation']),
            ),
            TaqaProfileInfoItem(
              label: 'Goal',
              value: _value(profile['fitness_goal']),
            ),
            TaqaProfileInfoItem(
              label: 'Training days',
              value: _value(profile['training_days']),
            ),
          ];
    final habitsTotal = _habits.length;
    final habitsChecked = _habits.where((habit) => habit.isCompleted).length;
    final dietAlert = _showDietLogPendingNote
        ? widget.client.sharedDietLogCount > 1
              ? 'New diet logs available (${widget.client.sharedDietLogCount})'
              : 'New diet log available'
        : null;

    final list = TaqaExpertClientView(
      name: _displayName(),
      userId: widget.client.userId,
      avatarUrl: _resolvedAvatarUrl(),
      activityStatus: _activityStatus ?? widget.client.activityStatus,
      personalInfoItems: personalInfoItems,
      habitsTotal: habitsTotal,
      habitsChecked: habitsChecked,
      habitsEnabled: _expertId != null,
      habitsError: _habitsError,
      analyticsAlert: _showTrainingPlanPendingNote
          ? "Client's plan not checked yet."
          : null,
      trainingPlanAlert: _showTrainingPlanPendingNote
          ? "Client's plan not checked yet."
          : null,
      dietAlert: dietAlert,
      supportChatAlert: _supportChatHasUnread
          ? 'Client sent a new message'
          : null,
      aiUpdatesAlert: _hasAiUpdatesPending ? _aiUpdatesStatusText() : null,
      trainingPlanLoading: _openingTrainingPlan,
      onOpenSupportChat: _openSupportChatPage,
      onOpenAnalytics: _openAnalyticsPage,
      onOpenTrainingPlan: _openTrainingPlanPage,
      onOpenHabits: _openHabitsPage,
      onOpenDietReview: _openDietReviewPage,
      onOpenAiUpdates: _openAiUpdatesPage,
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: TaqaPageAppBar(
        title: 'Client View',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: TaqaUiScale.w(32), height: TaqaUiScale.h(32)),
            IconButton(
              constraints: BoxConstraints.tightFor(
                width: TaqaUiScale.w(32),
                height: TaqaUiScale.h(32),
              ),
              padding: EdgeInsets.zero,
              splashRadius: TaqaUiScale.r(16),
              onPressed: (_loading || _detachingClient || _reportingClient)
                  ? null
                  : _reportClient,
              icon: _reportingClient
                  ? SizedBox(
                      width: TaqaUiScale.w(12),
                      height: TaqaUiScale.h(12),
                      child: CircularProgressIndicator(
                        strokeWidth: TaqaUiScale.w(1.5),
                        color: TaqaUiColors.recordRed,
                      ),
                    )
                  : const TaqaStopSignIcon(),
              tooltip: 'Report client',
            ),
            IconButton(
              constraints: BoxConstraints.tightFor(
                width: TaqaUiScale.w(32),
                height: TaqaUiScale.h(32),
              ),
              padding: EdgeInsets.zero,
              splashRadius: TaqaUiScale.r(16),
              onPressed: (_loading || _detachingClient || _reportingClient)
                  ? null
                  : _detachClient,
              icon: TaqaPersonRemoveIcon(loading: _detachingClient),
              tooltip: 'Detach client',
            ),
          ],
        ),
      ),
      body: TaqaRefreshIndicator(onRefresh: _load, child: list),
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
    AppToast.show(context, message, type: _clientToastType(message));
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
          ? 'Training plans pending verification (${widget.client.trainingPlanUncheckedCount})'
          : 'Training plan pending verification';
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
    final noteStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(10),
      fontWeight: FontWeight.w400,
      height: 12 / 10,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17,
    );
    final noteText = _formChecksError != null
        ? 'Only videos explicitly shared by this client are shown. $_formChecksError'
        : _sharedFormChecks.isEmpty
        ? 'Only videos explicitly shared by this client are shown. No videos available for review.'
        : 'Only videos explicitly shared by this client are shown.';

    return ListView(
      padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
      children: [
        Text(noteText, style: noteStyle),
        if (_showFormReviewPendingNote) ...[
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaClientAlertText(
            text:
                _sharedFormChecks
                        .where((item) => item.coachReview == null)
                        .length >
                    1
                ? 'Awaiting your reply (${_sharedFormChecks.where((item) => item.coachReview == null).length})'
                : 'Awaiting your reply',
          ),
        ],
        SizedBox(height: TaqaUiScale.h(10)),
        if (_formChecksError == null && _sharedFormChecks.isNotEmpty)
          ..._sharedFormChecks.map((item) {
            return Padding(
              padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
              child: TaqaClientDashboardCard(
                padding: 10,
                radius: 10,
                onTap: () => _openFormCheck(item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TaqaClientDashboardTitleText(
                            item.exerciseName,
                          ),
                        ),
                        SizedBox(width: TaqaUiScale.w(8)),
                        TaqaClientDashboardStatusPill(
                          label: item.coachReview == null
                              ? 'Pending reply'
                              : 'Reviewed',
                          color: item.coachReview == null
                              ? TaqaUiColors.recordRed
                              : const Color(0xFF4ADE80),
                        ),
                      ],
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    TaqaClientDashboardBodyText(
                      ((item.result.feedbackSummary ?? '').trim().isNotEmpty)
                          ? item.result.feedbackSummary!.trim()
                          : 'Open to review this form check.',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTrainingSuggestionsTab() {
    final noteStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(10),
      fontWeight: FontWeight.w400,
      height: 12 / 10,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    return ListView(
      padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'AI-generated progression reviews for this client.',
                style: noteStyle,
              ),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            TaqaOutlineTagButton(
              label: _generatingAiReview ? 'Working...' : 'Generate',
              width: TaqaUiScale.w(54),
              onTap: _generatingAiReview
                  ? null
                  : () => _generateAiReview(force: false),
            ),
          ],
        ),
        if (_showTrainingPlanPendingNote) ...[
          SizedBox(height: TaqaUiScale.h(8)),
          TaqaClientAlertText(
            text: widget.client.trainingPlanUncheckedCount > 1
                ? 'Training plans pending verification (${widget.client.trainingPlanUncheckedCount})'
                : 'Training plan pending verification',
          ),
        ],
        SizedBox(height: TaqaUiScale.h(10)),
        if (_clientReviews.isEmpty)
          const TaqaClientDashboardCard(
            padding: 12,
            radius: 10,
            child: TaqaClientDashboardBodyText(
              'No AI training suggestions yet. Generate one for this client from here.',
            ),
          )
        else
          ..._clientReviews.map(
            (review) => Padding(
              padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
              child: TaqaClientDashboardNavigationCard(
                title: review.weekStart ?? '-',
                description: '${review.itemCount} Suggestions',
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
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) {
              return Scaffold(
                backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
                appBar: TaqaPageAppBar(
                  backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
                  titleColor: TaqaUiColors.unnamedColor1c1d17,
                  title: 'AI Updates',
                ),
                body: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: TaqaUiScale.insetsLTRB(16, 12, 16, 0),
                        children: [
                          TaqaExpertClientCard(
                            name: widget.client.name ?? 'Client',
                            avatarUrl: widget.client.avatarUrl,
                            status: widget.client.activityStatus,
                            showStatus:
                                (widget.client.activityStatus ?? '')
                                    .trim()
                                    .isNotEmpty,
                            subtitle: 'User ID: ${widget.client.userId}',
                            details: const [
                              'Expected response within 24-48h',
                            ],
                            alerts: (_showFormReviewPendingNote ||
                                    _showTrainingPlanPendingNote)
                                ? [_aiUpdatesStatusText()]
                                : const [],
                          ),
                          SizedBox(height: TaqaUiScale.h(12)),
                          Row(
                            children: [
                              Expanded(
                                child: TaqaPillTab(
                                  label: 'Form Check',
                                  active: tabController.index == 0,
                                  onTap: () => tabController.animateTo(0),
                                ),
                              ),
                              SizedBox(width: TaqaUiScale.w(15)),
                              Expanded(
                                child: TaqaPillTab(
                                  label: 'Training Suggestion',
                                  active: tabController.index == 1,
                                  onTap: () => tabController.animateTo(1),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: TaqaUiScale.h(520),
                            child: TabBarView(
                              controller: tabController,
                              children: [
                                _buildFormCheckTab(),
                                _buildTrainingSuggestionsTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
