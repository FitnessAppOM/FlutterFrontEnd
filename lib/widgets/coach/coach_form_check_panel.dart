import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../consents/consent_manager.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/chat_attachment_file_service.dart';
import '../../services/coach/form_check_service.dart';
import '../../theme/app_theme.dart';
import 'chat_video_player_page.dart';

String _tr(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context).translate(key);
  return value == key ? fallback : value;
}

class CoachFormCheckPanel extends StatefulWidget {
  const CoachFormCheckPanel({super.key});

  @override
  State<CoachFormCheckPanel> createState() => _CoachFormCheckPanelState();
}

class _CoachFormCheckPanelState extends State<CoachFormCheckPanel> {
  final TextEditingController _exerciseController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  bool _consentAccepted = false;
  bool _saveToLibrary = false;
  String? _error;
  File? _selectedVideo;
  String? _selectedVideoName;
  int _selectedVideoBytes = 0;
  FormCheckUsage? _usage;
  List<FormCheckSubmission> _items = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _exerciseController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await FormCheckService.fetchSubmissions();
      if (!mounted) return;
      setState(() {
        _usage = response.usage;
        _items = response.items;
        _loading = false;
        _error = null;
      });
      _syncPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _syncPolling();
    }
  }

  void _syncPolling() {
    final needsPolling = _items.any((item) => item.isProcessing);
    if (needsPolling) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => _load(silent: true),
      );
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _pickVideo() async {
    final photosOk = await ConsentManager.requestPhotosJIT();
    if (!photosOk) {
      if (!mounted) return;
      _showToast(_tr(context, 'permissions_required', 'Permissions required'));
      return;
    }

    try {
      final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      if (!mounted) return;

      setState(() {
        _selectedVideo = file;
        _selectedVideoName = picked.name;
        _selectedVideoBytes = size;
      });
    } catch (_) {
      if (!mounted) return;
      _showToast(
        _tr(
          context,
          'coach_form_check_pick_video_failed',
          'Could not open video gallery on this device',
        ),
      );
    }
  }

  Future<void> _recordVideo() async {
    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (!mounted) return;
      setState(() {
        _selectedVideo = file;
        _selectedVideoName = picked.name;
        _selectedVideoBytes = size;
      });
    } catch (_) {
      if (!mounted) return;
      _showToast(
        _tr(
          context,
          'coach_form_check_record_failed',
          'Could not record video on this device',
        ),
      );
    }
  }

  Future<void> _submit() async {
    final video = _selectedVideo;
    final exerciseName = _exerciseController.text.trim();

    if (video == null) {
      _showToast(_tr(context, 'coach_form_check_pick_video', 'Pick a video'));
      return;
    }
    if (exerciseName.isEmpty) {
      _showToast(
        _tr(
          context,
          'coach_form_check_exercise_required',
          'Enter the exercise name',
        ),
      );
      return;
    }
    if (!_consentAccepted) {
      _showToast(
        _tr(
          context,
          'coach_form_check_consent_required',
          'Accept consent before uploading',
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final created = await FormCheckService.createSubmission(
        videoFile: video,
        exerciseName: exerciseName,
        consentAccepted: _consentAccepted,
        saveToLibrary: _saveToLibrary,
      );
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _selectedVideo = null;
        _selectedVideoName = null;
        _selectedVideoBytes = 0;
        _exerciseController.clear();
        _consentAccepted = false;
        _saveToLibrary = false;
        _items = [
          created,
          ..._items.where((item) => item.submissionId != created.submissionId),
        ];
        if (_usage != null) {
          _usage = FormCheckUsage(
            usedThisWeek: (_usage!.usedThisWeek + 1).clamp(
              0,
              _usage!.weeklyLimit,
            ),
            remainingThisWeek: (_usage!.remainingThisWeek - 1).clamp(
              0,
              _usage!.weeklyLimit,
            ),
            weeklyLimit: _usage!.weeklyLimit,
            weekStart: _usage!.weekStart,
            weekEnd: _usage!.weekEnd,
          );
        }
      });
      _syncPolling();
      _showToast(
        _tr(
          context,
          'coach_form_check_upload_success',
          'Form Check uploaded successfully',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleSave(FormCheckSubmission item) async {
    try {
      final updated = await FormCheckService.updateLibraryState(
        submissionId: item.submissionId,
        savedToLibrary: !item.savedToLibrary,
      );
      if (!mounted) return;

      setState(() {
        _items = _items
            .map(
              (existing) => existing.submissionId == updated.submissionId
                  ? updated
                  : existing,
            )
            .toList();
      });
      _showToast(
        updated.savedToLibrary
            ? _tr(
                context,
                'coach_form_check_saved_to_library',
                'Saved to Library',
              )
            : _tr(
                context,
                'coach_form_check_removed_from_library',
                'Removed from Library',
              ),
      );
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleShare(FormCheckSubmission item) async {
    try {
      final updated = await FormCheckService.updateShareState(
        submissionId: item.submissionId,
        shareWithCoach: !item.sharedWithCoach,
      );
      if (!mounted) return;

      setState(() {
        _items = _items
            .map(
              (existing) => existing.submissionId == updated.submissionId
                  ? updated
                  : existing,
            )
            .toList();
      });
      _showToast(
        updated.sharedWithCoach
            ? _tr(
                context,
                'coach_form_check_shared_for_review',
                'Video available for coach review',
              )
            : _tr(
                context,
                'coach_form_check_removed_from_review',
                'Removed from coach review',
              ),
      );
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteSubmission(FormCheckSubmission item) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: Text(
              _tr(
                dialogContext,
                'coach_form_check_delete_title',
                'Delete Form Check',
              ),
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              _tr(
                dialogContext,
                'coach_form_check_delete_body',
                'This removes the submission and its analysis from your account.',
              ),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_tr(dialogContext, 'common_close', 'Close')),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  _tr(
                    dialogContext,
                    'coach_form_check_delete_confirm',
                    'Delete',
                  ),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await FormCheckService.deleteSubmission(item.submissionId);
      if (!mounted) return;

      setState(() {
        _items = _items
            .where((existing) => existing.submissionId != item.submissionId)
            .toList();
      });
      _showToast(
        _tr(context, 'coach_form_check_delete_success', 'Form Check deleted'),
      );
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''));
    }
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
      _showToast(
        'Could not open video: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return DateFormat('MMM d, HH:mm').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _HeaderCard(
          title: _tr(context, 'coach_tab_form_check', 'Form Check'),
          subtitle: _tr(
            context,
            'coach_form_check_intro',
            'Upload a short exercise video for AI feedback on movement quality and technique.',
          ),
          usage: usage,
        ),
        const SizedBox(height: 14),
        _ConsentCard(
          title: _tr(
            context,
            'coach_form_check_consent_title',
            'Consent required before upload',
          ),
          body: _tr(
            context,
            'coach_form_check_consent_body',
            'Your video will be analyzed by Taqa Agent and stored on Taqa Fitness servers for up to 30 days unless you save it to your Library. You can delete it at any time.',
          ),
        ),
        const SizedBox(height: 14),
        _UploadCard(
          exerciseController: _exerciseController,
          consentAccepted: _consentAccepted,
          saveToLibrary: _saveToLibrary,
          selectedVideoName: _selectedVideoName,
          selectedVideoBytes: _selectedVideoBytes,
          submitting: _submitting,
          onPickVideo: _pickVideo,
          onRecordVideo: _recordVideo,
          onConsentChanged: (value) {
            setState(() {
              _consentAccepted = value ?? false;
            });
          },
          onSaveToLibraryChanged: (value) {
            setState(() {
              _saveToLibrary = value;
            });
          },
          onSubmit: _submit,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                _tr(context, 'coach_form_check_recent', 'Recent Form Checks'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh, color: Colors.white70),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (_error != null)
          _EmptyStateCard(
            title: _tr(
              context,
              'coach_form_check_load_failed',
              'Could not load Form Checks',
            ),
            subtitle: _error!,
          )
        else if (_items.isEmpty)
          _EmptyStateCard(
            title: _tr(
              context,
              'coach_form_check_empty_title',
              'No Form Checks yet',
            ),
            subtitle: _tr(
              context,
              'coach_form_check_empty_body',
              'Upload your first short exercise clip to get AI feedback.',
            ),
          )
        else
          ..._items
              .take(8)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _SubmissionCard(
                    item: item,
                    createdAtLabel: _formatDate(item.createdAt),
                    deleteAfterLabel: _formatDate(item.deleteAfter),
                    onOpenVideo: () => _openVideoInApp(
                      item.originalVideoUrl,
                      title: item.exerciseName,
                    ),
                    onOpenOverlay: item.result.overlayUrl == null
                        ? null
                        : () => _openVideoInApp(
                            item.result.overlayUrl,
                            title: '${item.exerciseName} (Overlay)',
                          ),
                    onToggleShare: () => _toggleShare(item),
                    onToggleSave: () => _toggleSave(item),
                    onDelete: () => _deleteSubmission(item),
                  ),
                ),
              ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.usage,
  });

  final String title;
  final String subtitle;
  final FormCheckUsage? usage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          if (usage != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _UsageChip(
                  label: '${usage!.usedThisWeek}/${usage!.weeklyLimit} used',
                ),
                _UsageChip(label: '${usage!.remainingThisWeek} remaining'),
                const _UsageChip(label: '5-15 sec, MP4/MOV'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.lightBlueAccent.withValues(alpha: 0.22),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user_outlined,
              color: Colors.lightBlueAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.exerciseController,
    required this.consentAccepted,
    required this.saveToLibrary,
    required this.selectedVideoName,
    required this.selectedVideoBytes,
    required this.submitting,
    required this.onPickVideo,
    required this.onRecordVideo,
    required this.onConsentChanged,
    required this.onSaveToLibraryChanged,
    required this.onSubmit,
  });

  final TextEditingController exerciseController;
  final bool consentAccepted;
  final bool saveToLibrary;
  final String? selectedVideoName;
  final int selectedVideoBytes;
  final bool submitting;
  final VoidCallback onPickVideo;
  final VoidCallback onRecordVideo;
  final ValueChanged<bool?> onConsentChanged;
  final ValueChanged<bool> onSaveToLibraryChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              context,
              'coach_form_check_upload_title',
              'Upload a new Form Check',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: exerciseController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: _tr(
                context,
                'coach_form_check_exercise_label',
                'Exercise',
              ),
              hintText: _tr(
                context,
                'coach_form_check_exercise_hint',
                'Example: Squat or Romanian deadlift',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: submitting ? null : onPickVideo,
                  icon: const Icon(
                    Icons.video_library_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    _tr(context, 'coach_form_check_pick_video', 'Pick a video'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white12),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: submitting ? null : onRecordVideo,
                  icon: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    _tr(
                      context,
                      'coach_form_check_record_video',
                      'Record video',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white12),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          if (selectedVideoName != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_tr(context, 'coach_form_check_selected_video', 'Selected')}: $selectedVideoName',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${_tr(context, 'coach_form_check_file_size', 'File size')}: ${_formatBytes(selectedVideoBytes)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          CheckboxListTile(
            value: consentAccepted,
            onChanged: submitting ? null : onConsentChanged,
            activeColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tr(
                context,
                'coach_form_check_accept_consent',
                'I understand this video will be analyzed and stored according to the consent notice above.',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SwitchListTile(
            value: saveToLibrary,
            onChanged: submitting ? null : onSaveToLibraryChanged,
            activeThumbColor: AppColors.accent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              _tr(
                context,
                'coach_form_check_save_to_library',
                'Save this result to Library',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _tr(
                        context,
                        'coach_form_check_submit',
                        'Upload and analyze',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white54, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.item,
    required this.createdAtLabel,
    required this.deleteAfterLabel,
    required this.onOpenVideo,
    this.onOpenOverlay,
    required this.onToggleShare,
    required this.onToggleSave,
    required this.onDelete,
  });

  final FormCheckSubmission item;
  final String createdAtLabel;
  final String deleteAfterLabel;
  final VoidCallback onOpenVideo;
  final VoidCallback? onOpenOverlay;
  final VoidCallback onToggleShare;
  final VoidCallback onToggleSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'completed' => AppColors.successGreen,
      'failed' => AppColors.errorRed,
      'processing' => Colors.orangeAccent,
      'queued' => Colors.amberAccent,
      _ => Colors.white54,
    };
    final hasCoachReply =
        item.coachReviewReplies.isNotEmpty ||
        ((item.coachReview?.reviewText ?? '').trim().isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
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
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Meta(
                label:
                    '${_tr(context, 'coach_form_check_created', 'Created')}: $createdAtLabel',
              ),
              _Meta(
                label:
                    '${_tr(context, 'coach_form_check_duration', 'Duration')}: ${item.durationSeconds.toStringAsFixed(1)}s',
              ),
              _Meta(
                label:
                    '${_tr(context, 'coach_form_check_delete_after', 'Delete after')}: $deleteAfterLabel',
              ),
              if (item.sharedWithCoach && !hasCoachReply)
                _Meta(
                  label: _tr(
                    context,
                    'coach_form_check_review_available',
                    'Video available for review',
                  ),
                ),
              if (hasCoachReply)
                _Meta(
                  label: _tr(
                    context,
                    'coach_form_check_replied',
                    'Coach replied',
                  ),
                ),
            ],
          ),
          if (item.isProcessing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tr(
                      context,
                      'coach_form_check_processing',
                      'Analyzing your movement...',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ] else if (item.isFailed) ...[
            const SizedBox(height: 12),
            Text(
              item.failureReason?.isNotEmpty == true
                  ? item.failureReason!
                  : _tr(
                      context,
                      'coach_form_check_failed_body',
                      'This Form Check could not be processed.',
                    ),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ] else ...[
            if ((item.result.feedbackSummary ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.result.feedbackSummary!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.result.feedbackBullets.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...item.result.feedbackBullets.map(
                (bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.open_in_new,
                label: _tr(
                  context,
                  'coach_form_check_open_video',
                  'Open video',
                ),
                onTap: onOpenVideo,
              ),
              if (onOpenOverlay != null)
                _ActionButton(
                  icon: Icons.insights_outlined,
                  label: _tr(
                    context,
                    'coach_form_check_open_overlay',
                    'Open overlay',
                  ),
                  onTap: onOpenOverlay!,
                ),
              _ActionButton(
                icon: item.sharedWithCoach
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: item.sharedWithCoach
                    ? _tr(
                        context,
                        'coach_form_check_hide_from_coach',
                        'Remove from coach review',
                      )
                    : _tr(
                        context,
                        'coach_form_check_show_to_coach',
                        'Show to coach for review',
                      ),
                onTap: onToggleShare,
                foreground: item.sharedWithCoach
                    ? Colors.orangeAccent
                    : Colors.lightBlueAccent,
              ),
              _ActionButton(
                icon: item.savedToLibrary
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
                label: item.savedToLibrary
                    ? _tr(
                        context,
                        'coach_form_check_remove_from_library',
                        'Remove from Library',
                      )
                    : _tr(
                        context,
                        'coach_form_check_save_action',
                        'Save to Library',
                      ),
                onTap: onToggleSave,
              ),
              _ActionButton(
                icon: Icons.delete_outline,
                label: _tr(
                  context,
                  'coach_form_check_delete_confirm',
                  'Delete',
                ),
                onTap: onDelete,
                foreground: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
