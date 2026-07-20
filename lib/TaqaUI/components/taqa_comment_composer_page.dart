import 'dart:async';

import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_expert_dashboard_ui.dart';
import 'taqa_filled_button.dart';
import 'taqa_outline_tag_button.dart';
import 'taqa_page_app_bar.dart';
import 'taqa_toast.dart';

/// A compact, reusable TaqaUI page for composing a comment against a named
/// record, such as a logged meal or a training set.
class TaqaCommentComposerPage extends StatefulWidget {
  const TaqaCommentComposerPage({
    super.key,
    required this.subject,
    required this.onSubmit,
    this.title = 'Leave Comment',
    this.hintText = 'Write a comment...',
    this.onStartVoiceNote,
    this.onStopVoiceNote,
    this.onSendVoiceNote,
    this.onCancelVoiceNote,
  });

  final String title;
  final String subject;
  final String hintText;
  final Future<void> Function(String comment) onSubmit;
  final Future<bool> Function()? onStartVoiceNote;
  final Future<bool> Function()? onStopVoiceNote;
  final Future<void> Function(String comment)? onSendVoiceNote;
  final Future<void> Function()? onCancelVoiceNote;

  @override
  State<TaqaCommentComposerPage> createState() =>
      _TaqaCommentComposerPageState();
}

class _TaqaCommentComposerPageState extends State<TaqaCommentComposerPage> {
  final _controller = TextEditingController();
  bool _sending = false;
  int _voiceState = 0; // 0 idle, 1 recording, 2 ready to send

  bool get _supportsVoiceNotes =>
      widget.onStartVoiceNote != null &&
      widget.onStopVoiceNote != null &&
      widget.onSendVoiceNote != null &&
      widget.onCancelVoiceNote != null;

  @override
  void dispose() {
    if (_voiceState != 0 && widget.onCancelVoiceNote != null) {
      unawaited(widget.onCancelVoiceNote!());
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _controller.text.trim();
    if ((comment.isEmpty && _voiceState != 2) || _sending) return;
    setState(() => _sending = true);
    try {
      if (_voiceState == 2 && widget.onSendVoiceNote != null) {
        await widget.onSendVoiceNote!(comment);
      } else {
        await widget.onSubmit(comment);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          'Comment could not be sent.',
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startVoice() async {
    if (_sending || widget.onStartVoiceNote == null) return;
    setState(() => _sending = true);
    try {
      if (await widget.onStartVoiceNote!() && mounted) {
        setState(() => _voiceState = 1);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _stopVoice() async {
    if (_sending || widget.onStopVoiceNote == null) return;
    setState(() => _sending = true);
    try {
      if (await widget.onStopVoiceNote!() && mounted) {
        setState(() => _voiceState = 2);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelVoice() async {
    if (_sending || widget.onCancelVoiceNote == null) return;
    await widget.onCancelVoiceNote!();
    if (mounted) setState(() => _voiceState = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(title: widget.title),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 12, 17, 24),
          children: [
            TaqaManagementListCard(
              radius: 15,
              showBorder: false,
              padding: TaqaUiScale.insetsLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subject,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(10)),
                  TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 8,
                    autofocus: true,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 21 / 15,
                      color: TaqaUiColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        color: TaqaUiColors.unnamedColorE3e3e3,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: TaqaUiColors.charcoal,
                          width: .5,
                        ),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: TaqaUiColors.charcoal,
                          width: .5,
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: TaqaUiColors.charcoal,
                          width: .5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(16)),
                  if (_supportsVoiceNotes) ...[
                    if (_voiceState == 0)
                      TaqaOutlineTagButton(
                        label: 'Record Voice',
                        width: TaqaUiScale.w(116),
                        height: TaqaUiScale.h(30),
                        onTap: _sending ? null : _startVoice,
                        icon: Icon(
                          Icons.mic,
                          size: TaqaUiScale.w(10),
                          color: TaqaUiColors.charcoal,
                        ),
                      )
                    else if (_voiceState == 1)
                      TaqaOutlineTagButton(
                        label: 'Stop Recording',
                        width: TaqaUiScale.w(130),
                        height: TaqaUiScale.h(30),
                        onTap: _sending ? null : _stopVoice,
                        icon: Icon(
                          Icons.stop,
                          size: TaqaUiScale.w(10),
                          color: TaqaUiColors.recordRed,
                        ),
                        borderColor: TaqaUiColors.recordRed,
                      )
                    else
                      TaqaOutlineTagButton(
                        label: 'Cancel Voice',
                        width: TaqaUiScale.w(96),
                        height: TaqaUiScale.h(30),
                        onTap: _sending ? null : _cancelVoice,
                      ),
                    SizedBox(height: TaqaUiScale.h(12)),
                  ],
                  TaqaFilledButton(
                    label: 'Leave Comment',
                    onTap: _sending ? null : _submit,
                    loading: _sending,
                    height: 45,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
