import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/coach/coach_support_chat_service.dart';
import '../../theme/app_theme.dart';

class CoachChatPanel extends StatefulWidget {
  const CoachChatPanel({super.key});

  @override
  State<CoachChatPanel> createState() => _CoachChatPanelState();
}

class _CoachChatPanelState extends State<CoachChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  CoachSupportChatState? _chatState;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.fetchClientThread();
      if (!mounted) return;
      setState(() {
        _chatState = state;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatState = null;
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.sendClientTextMessage(
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _chatState = state;
        _sending = false;
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Failed to send message')),
      );
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatDurationShort(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  String _firstNameOnly(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'Coach';
    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Coach';
    return parts.first;
  }

  String _buildSlaLine(CoachSupportChatSla sla) {
    if (sla.status == 'no_coach_assigned') {
      return 'Connect to a coach to start support chat.';
    }
    if (sla.status == 'waiting_for_coach') {
      final dueAt = sla.expectedResponseDueAt;
      if (dueAt == null) return 'Expected response within: --';
      final remaining = dueAt.toLocal().difference(DateTime.now());
      final safe = remaining.isNegative ? Duration.zero : remaining;
      return 'Expected response within: ${_formatDurationShort(safe)}';
    }
    if (sla.status == 'breached') {
      return 'Expected response window exceeded.';
    }
    if (sla.status == 'responded') {
      return 'Coach responded.';
    }
    return 'Expected response within: ${sla.targetWindowHoursMin}-${sla.targetWindowHoursMax}h';
  }

  Widget _buildSupportHeader(CoachSupportChatState state) {
    final thread = state.thread;
    final coachName = thread?.coachName.trim() ?? '';
    final coachFirstName = _firstNameOnly(coachName);
    final chips = <Widget>[
      _SupportChip(
        label: state.supportsText ? 'Text: On' : 'Text: Off',
        color: state.supportsText ? Colors.greenAccent : Colors.white54,
      ),
      const _SupportChip(label: 'Image: Soon', color: Colors.white54),
      const _SupportChip(label: 'Video: Soon', color: Colors.white54),
      const _SupportChip(label: 'Voice: Soon', color: Colors.white54),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(12),
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
              const Icon(
                Icons.support_agent,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  coachName.isEmpty
                      ? 'Support chat'
                      : 'Support chat with $coachFirstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildSlaLine(state.sla),
            style: TextStyle(
              color: state.sla.breached ? Colors.orangeAccent : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target response window: ${state.sla.targetWindowHoursMin}-${state.sla.targetWindowHoursMax} hours',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CoachSupportChatMessage message) {
    final isClient = message.isFromClient;
    final senderName = message.senderRole == 'coach'
        ? _firstNameOnly(message.senderName)
        : message.senderName;
    final bubbleColor = isClient
        ? AppColors.accent.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = isClient
        ? AppColors.accent.withValues(alpha: 0.6)
        : Colors.white10;

    return Align(
      alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: isClient
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isClient)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              message.messageText,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(message.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final state = _chatState;
    if (state == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              _error ?? 'Could not load chat',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final messages = state.messages;
    final noCoach =
        state.sla.status == 'no_coach_assigned' || state.thread == null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildSupportHeader(state),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        if (noCoach)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'No coach is currently assigned. Once connected, this chat will be enabled.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        if (!noCoach && messages.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'No messages yet. Send your first text message to your coach.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        if (!noCoach) ...messages.map(_buildMessageBubble),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildComposer() {
    final state = _chatState;
    final disabled =
        _loading ||
        _sending ||
        state == null ||
        state.thread == null ||
        !state.supportsText;

    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.black,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !disabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: disabled
                      ? 'Chat unavailable'
                      : 'Write a message to your coach',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: disabled ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(72, 44),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(onRefresh: _loadChat, child: _buildBody()),
        ),
        _buildComposer(),
      ],
    );
  }
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
