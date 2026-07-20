import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_mini_tag.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_refresh_indicator.dart';
import '../../TaqaUI/components/taqa_switch.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_underline_field.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../consents/consent_manager.dart';
import '../../core/user_friendly_error.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/chat_attachment_file_service.dart';
import '../../services/coach/form_check_service.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  bool _consentAccepted = false;
  bool _saveToLibrary = false;
  String? _error;
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
        _error = userFriendlyErrorMessage(
          e,
          fallback: 'Could not load Form Check. Please try again.',
        );
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
    if (_submitting) return;
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

    final photosOk = await ConsentManager.requestPhotosJIT();
    if (!photosOk) {
      if (!mounted) return;
      _showToast(_tr(context, 'permissions_required', 'Permissions required'));
      return;
    }

    try {
      final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      if (!mounted) return;
      await _promptExerciseNameAndSubmit(File(picked.path));
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
    if (_submitting) return;
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

    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );
      if (picked == null) return;
      if (!mounted) return;
      await _promptExerciseNameAndSubmit(File(picked.path));
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

  Future<void> _promptExerciseNameAndSubmit(File video) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => TaqaPopupDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr(dialogContext, 'coach_form_check_exercise_label', 'Exercise'),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaUnderlineTextField(
              controller: controller,
              hint: _tr(
                dialogContext,
                'coach_form_check_exercise_hint',
                'Example: Squat or Romanian deadlift',
              ),
            ),
            SizedBox(height: TaqaUiScale.h(20)),
            Row(
              children: [
                Expanded(
                  child: TaqaTextActionButton(
                    label: _tr(dialogContext, 'common_close', 'Cancel'),
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(10)),
                Expanded(
                  child: TaqaFilledButton(
                    label: _tr(
                      dialogContext,
                      'coach_form_check_submit',
                      'Continue',
                    ),
                    height: 45,
                    onTap: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) {
                        Navigator.of(dialogContext).pop(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final exerciseName = (name ?? '').trim();
    if (exerciseName.isEmpty) return;
    await _submitVideo(video, exerciseName);
  }

  Future<void> _submitVideo(File video, String exerciseName) async {
    setState(() => _submitting = true);
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
      _showToast(
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not upload Form Check. Please try again.',
        ),
      );
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
      _showToast(
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not update this item. Please try again.',
        ),
      );
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
      _showToast(
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not update this item. Please try again.',
        ),
      );
    }
  }

  Future<void> _deleteSubmission(FormCheckSubmission item) async {
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: _tr(context, 'coach_form_check_delete_title', 'Delete Form Check'),
      message: _tr(
        context,
        'coach_form_check_delete_body',
        'This removes the submission and its analysis from your account.',
      ),
      confirmLabel: _tr(
        context,
        'coach_form_check_delete_confirm',
        'Delete',
      ),
      cancelLabel: _tr(context, 'common_close', 'Close'),
    );
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
      _showToast(
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not delete this item. Please try again.',
        ),
      );
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
        'Could not open video: ${userFriendlyErrorMessage(e, fallback: 'Please try again.')}',
      );
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    AppToast.show(context, message);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return DateFormat('MMM d, HH:mm').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;

    return TaqaRefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: TaqaUiScale.insetsLTRB(16, 12, 16, 20),
        children: [
          Text(
            _tr(context, 'coach_tab_form_check', 'Form Check'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(25),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.charcoal,
              height: 25 / 25,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          Text(
            _tr(
              context,
              'coach_form_check_intro',
              'Upload a 5-15 second short exercise video for AI feedback on movement quality and technique.',
            ),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.charcoal,
              height: 18 / 15,
            ),
          ),
          if (usage != null) ...[
            SizedBox(height: TaqaUiScale.h(10)),
            Wrap(
              spacing: TaqaUiScale.w(8),
              runSpacing: TaqaUiScale.h(8),
              children: [
                _UsageChip(
                  label:
                      '${usage.usedThisWeek}/${usage.weeklyLimit} USED'
                          .toUpperCase(),
                ),
                const _UsageChip(label: 'MP4/MOV'),
              ],
            ),
          ],
          SizedBox(height: TaqaUiScale.h(14)),
          _ConsentCard(
            title: _tr(
              context,
              'coach_form_check_consent_title',
              'Consent Required Before Upload',
            ),
            body: _tr(
              context,
              'coach_form_check_consent_body',
              'Your video will be analyzed by Taqa Agent and stored on Taqa Fitness servers for up to 30 days unless you save it to your Library. You can delete it at any time.',
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          _UploadCard(
            consentAccepted: _consentAccepted,
            saveToLibrary: _saveToLibrary,
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
          ),
          SizedBox(height: TaqaUiScale.h(18)),
          Text(
            _tr(context, 'coach_form_check_recent', 'Recent Form Checks'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(16),
            ),
          ),
          if (_loading)
            Padding(
              padding: EdgeInsets.only(top: TaqaUiScale.h(24)),
              child: const Center(
                child: CircularProgressIndicator(color: TaqaUiColors.accent),
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
                    padding: EdgeInsets.only(top: TaqaUiScale.h(10)),
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
      padding: TaqaUiScale.insetsLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(8),
        border: Border.all(color: TaqaUiColors.charcoal.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
          fontSize: TaqaUiScale.sp(10),
          fontWeight: FontWeight.w600,
        ),
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
        color: TaqaUiColors.charcoal,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.white,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(15),
              height: 25 / 15,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            body,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.white,
              fontWeight: FontWeight.w400,
              fontSize: TaqaUiScale.sp(15),
              height: 21 / 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.consentAccepted,
    required this.saveToLibrary,
    required this.submitting,
    required this.onPickVideo,
    required this.onRecordVideo,
    required this.onConsentChanged,
    required this.onSaveToLibraryChanged,
  });

  final bool consentAccepted;
  final bool saveToLibrary;
  final bool submitting;
  final VoidCallback onPickVideo;
  final VoidCallback onRecordVideo;
  final ValueChanged<bool?> onConsentChanged;
  final ValueChanged<bool> onSaveToLibraryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              context,
              'coach_form_check_upload_title',
              'Upload New Form Check',
            ),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(15),
              height: 25 / 15,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(17)),
          Row(
            children: [
              Expanded(
                child: _FormCheckActionButton(
                  label: _tr(
                    context,
                    'coach_form_check_pick_video',
                    'Upload Video',
                  ),
                  onTap: submitting ? null : onPickVideo,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: _FormCheckActionButton(
                  label: _tr(
                    context,
                    'coach_form_check_record_video',
                    'Record Video',
                  ),
                  onTap: submitting ? null : onRecordVideo,
                ),
              ),
            ],
          ),
          if (submitting) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            Row(
              children: [
                SizedBox(
                  width: TaqaUiScale.w(14),
                  height: TaqaUiScale.w(14),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TaqaUiColors.accent,
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(10)),
                Text(
                  _tr(
                    context,
                    'coach_form_check_uploading',
                    'Uploading and analyzing...',
                  ),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                    fontSize: TaqaUiScale.sp(12),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: TaqaUiScale.h(20)),
          GestureDetector(
            onTap: submitting
                ? null
                : () => onConsentChanged(!consentAccepted),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(left: TaqaUiScale.w(9)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: TaqaUiScale.w(10),
                    height: TaqaUiScale.w(10),
                    margin: EdgeInsets.only(top: TaqaUiScale.h(2)),
                    decoration: BoxDecoration(
                      color: consentAccepted
                          ? TaqaUiColors.accent
                          : TaqaUiColors.white,
                      border: Border.all(
                        color: consentAccepted
                            ? TaqaUiColors.accent
                            : TaqaUiColors.charcoal.withValues(alpha: 0.8),
                        width: 0.5,
                      ),
                    ),
                    child: consentAccepted
                        ? Icon(
                            Icons.check,
                            color: TaqaUiColors.white,
                            size: TaqaUiScale.w(9),
                          )
                        : null,
                  ),
                  SizedBox(width: TaqaUiScale.w(13)),
                  Expanded(
                    child: Text(
                      _tr(
                        context,
                        'coach_form_check_accept_consent',
                        'I understand this video will be analyzed and stored according to the consent notice above',
                      ),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        color: TaqaUiColors.charcoal,
                        fontWeight: FontWeight.w400,
                        fontSize: TaqaUiScale.sp(10),
                        height: 12 / 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(16)),
          Row(
            children: [
              Text(
                _tr(
                  context,
                  'coach_form_check_save_to_library',
                  'Save to Library',
                ),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: TaqaUiColors.charcoal,
                  fontWeight: FontWeight.w700,
                  fontSize: TaqaUiScale.sp(13),
                ),
              ),
              const Spacer(),
              TaqaSwitch(
                value: saveToLibrary,
                onChanged: submitting ? null : onSaveToLibraryChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormCheckActionButton extends StatelessWidget {
  const _FormCheckActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.unnamedColorE3e3e3,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onTap,
        child: Container(
          height: TaqaUiScale.h(45),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w600,
              fontSize: TaqaUiScale.sp(10),
              height: 12 / 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: TaqaUiScale.h(8)),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: TaqaUiScale.sp(15),
              height: 25 / 15,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w400,
              fontSize: TaqaUiScale.sp(15),
              height: 21 / 15,
            ),
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
    final hasCoachReply =
        item.coachReviewReplies.isNotEmpty ||
        ((item.coachReview?.reviewText ?? '').trim().isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.exerciseName,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    color: TaqaUiColors.charcoal,
                    fontWeight: FontWeight.w700,
                    fontSize: TaqaUiScale.sp(15),
                  ),
                ),
              ),
              TaqaMiniTag(label: item.status.toUpperCase()),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Wrap(
            spacing: TaqaUiScale.w(8),
            runSpacing: TaqaUiScale.h(8),
            children: [
              TaqaMiniTag(
                label:
                    '${_tr(context, 'coach_form_check_created', 'Created')}: $createdAtLabel',
              ),
              TaqaMiniTag(
                label:
                    '${_tr(context, 'coach_form_check_duration', 'Duration')}: ${item.durationSeconds.toStringAsFixed(1)}s',
              ),
              TaqaMiniTag(
                label:
                    '${_tr(context, 'coach_form_check_delete_after', 'Delete after')}: $deleteAfterLabel',
              ),
              if (item.sharedWithCoach && !hasCoachReply)
                TaqaMiniTag(
                  label: _tr(
                    context,
                    'coach_form_check_review_available',
                    'Video available for review',
                  ),
                ),
              if (hasCoachReply)
                TaqaMiniTag(
                  label: _tr(
                    context,
                    'coach_form_check_replied',
                    'Coach replied',
                  ),
                ),
            ],
          ),
          if (item.isProcessing) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            Row(
              children: [
                SizedBox(
                  height: TaqaUiScale.w(16),
                  width: TaqaUiScale.w(16),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TaqaUiColors.accent,
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(10)),
                Expanded(
                  child: Text(
                    _tr(
                      context,
                      'coach_form_check_processing',
                      'Analyzing your movement...',
                    ),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (item.isFailed) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            Text(
              item.failureReason?.isNotEmpty == true
                  ? item.failureReason!
                  : _tr(
                      context,
                      'coach_form_check_failed_body',
                      'This Form Check could not be processed.',
                    ),
              style: const TextStyle(color: Color(0xFFE84C4F)),
            ),
          ] else ...[
            if ((item.result.feedbackSummary ?? '').trim().isNotEmpty) ...[
              SizedBox(height: TaqaUiScale.h(12)),
              Text(
                item.result.feedbackSummary!,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: TaqaUiColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.result.feedbackBullets.isNotEmpty) ...[
              SizedBox(height: TaqaUiScale.h(10)),
              ...item.result.feedbackBullets.map(
                (bullet) => Padding(
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(6)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: TaqaUiScale.h(6)),
                        child: Icon(
                          Icons.circle,
                          size: TaqaUiScale.sp(7),
                          color: TaqaUiColors.accent,
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(8)),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: 0.8,
                            ),
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
          SizedBox(height: TaqaUiScale.h(12)),
          Wrap(
            spacing: TaqaUiScale.w(8),
            runSpacing: TaqaUiScale.h(8),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = TaqaUiColors.charcoal.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: TaqaUiScale.radius(999),
      child: Container(
        padding: TaqaUiScale.insetsLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: TaqaUiScale.radius(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: TaqaUiScale.sp(16), color: color),
            SizedBox(width: TaqaUiScale.w(6)),
            Text(
              label,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: color,
                fontSize: TaqaUiScale.sp(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
