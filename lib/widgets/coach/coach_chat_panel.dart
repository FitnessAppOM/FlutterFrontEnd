import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/base_url.dart';
import '../../services/coach/chat_attachment_file_service.dart';
import '../../services/coach/coach_support_chat_service.dart';
import '../../services/coach/voice_note_audio_service.dart';
import '../../theme/app_theme.dart';

class CoachChatPanel extends StatefulWidget {
  const CoachChatPanel({super.key});

  @override
  State<CoachChatPanel> createState() => _CoachChatPanelState();
}

class _CoachChatPanelState extends State<CoachChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _loading = true;
  bool _loadingThread = false;
  bool _sending = false;
  bool _isRecordingVoice = false;
  bool _openingAttachment = false;
  String? _error;
  String? _recordingVoicePath;
  File? _pendingAttachmentFile;
  String? _pendingAttachmentType;
  String? _pendingAttachmentName;
  String? _activeVoiceKey;
  CoachSupportChatState? _chatState;
  List<CoachSupportChatThreadSummary> _coachThreads =
      const <CoachSupportChatThreadSummary>[];
  int? _selectedCoachUserId;
  int? _focusedMessageId;
  Timer? _ticker;
  StreamSubscription<PlayerState>? _voicePlayerSub;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _voicePlayerSub = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (!state.playing &&
          state.processingState == ProcessingState.completed) {
        setState(() {
          _activeVoiceKey = null;
        });
      }
    });
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _voicePlayerSub?.cancel();
    if (_isRecordingVoice) {
      unawaited(_audioRecorder.stop());
    }
    unawaited(_audioRecorder.dispose());
    unawaited(_voicePlayer.dispose());
    final pendingVoicePath = _pendingAttachmentType == 'voice'
        ? _pendingAttachmentFile?.path
        : null;
    if (pendingVoicePath != null && pendingVoicePath.trim().isNotEmpty) {
      unawaited(_deleteLocalFile(pendingVoicePath));
    }
    _messageController.dispose();
    super.dispose();
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

  String? _normalizeAvatarUrl(String? rawValue) {
    final raw = (rawValue ?? '').trim();
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

  GlobalKey _messageKeyFor(int messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  Future<void> _reportMessage(CoachSupportChatMessage message) async {
    try {
      await CoachSupportChatService.reportMessage(messageId: message.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message reported.')));
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.isEmpty ? 'Failed to report message.' : text),
        ),
      );
    }
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

  String? _inferAttachmentType({String? extension, String? mimeType}) {
    final ext = (extension ?? '').trim().toLowerCase();
    final mime = (mimeType ?? '').trim().toLowerCase();
    const imageExt = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
    const videoExt = {'.mp4', '.mov', '.m4v', '.webm'};
    const voiceExt = {'.aac', '.m4a', '.mp3', '.wav', '.ogg', '.webm'};
    const docExt = {'.pdf', '.doc', '.docx', '.txt', '.rtf'};

    if (imageExt.contains(ext) || mime.startsWith('image/')) return 'image';
    if (videoExt.contains(ext) || mime.startsWith('video/')) return 'video';
    if (voiceExt.contains(ext) || mime.startsWith('audio/')) return 'voice';
    if (docExt.contains(ext)) return 'document';
    if (mime == 'application/pdf' ||
        mime == 'application/msword' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
        mime == 'text/plain' ||
        mime == 'application/rtf' ||
        mime == 'text/rtf') {
      return 'document';
    }
    return null;
  }

  Future<void> _pickAttachment() async {
    if (_sending || _isRecordingVoice) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'mp4',
        'mov',
        'm4v',
        'webm',
        'pdf',
        'doc',
        'docx',
        'txt',
        'rtf',
        'aac',
        'm4a',
        'mp3',
        'wav',
        'ogg',
      ],
    );
    if (!mounted) return;
    final picked = result?.files.isNotEmpty == true
        ? result!.files.first
        : null;
    if (picked == null || (picked.path ?? '').trim().isEmpty) return;

    final ext = picked.extension == null || picked.extension!.trim().isEmpty
        ? ''
        : '.${picked.extension!.trim().toLowerCase()}';
    final type = _inferAttachmentType(extension: ext);
    if (type == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unsupported file type.')));
      return;
    }

    final previousVoicePath = _pendingAttachmentType == 'voice'
        ? _pendingAttachmentFile?.path
        : null;
    setState(() {
      _pendingAttachmentFile = File(picked.path!);
      _pendingAttachmentType = type;
      _pendingAttachmentName = picked.name.trim().isEmpty
          ? 'attachment$ext'
          : picked.name.trim();
      _activeVoiceKey = null;
    });
    if (previousVoicePath != null && previousVoicePath.trim().isNotEmpty) {
      await _deleteLocalFile(previousVoicePath);
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_sending || _isRecordingVoice) return;
    if (_pendingAttachmentFile != null && _pendingAttachmentType != 'voice') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove selected attachment first.')),
      );
      return;
    }
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/support_chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _recordingVoicePath = path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start recording: $e')));
    }
  }

  Future<void> _finishVoiceRecording({bool discard = false}) async {
    if (!_isRecordingVoice) return;
    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (_) {}
    final fallbackPath = _recordingVoicePath;
    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordingVoicePath = null;
    });
    final finalPath = (recordedPath ?? fallbackPath ?? '').trim();
    if (finalPath.isEmpty) {
      return;
    }
    if (discard) {
      await _deleteLocalFile(finalPath);
      return;
    }
    final previousVoicePath = _pendingAttachmentType == 'voice'
        ? _pendingAttachmentFile?.path
        : null;
    setState(() {
      _pendingAttachmentFile = File(finalPath);
      _pendingAttachmentType = 'voice';
      _pendingAttachmentName = 'voice_note.m4a';
      _activeVoiceKey = null;
    });
    if (previousVoicePath != null &&
        previousVoicePath.trim().isNotEmpty &&
        previousVoicePath != finalPath) {
      await _deleteLocalFile(previousVoicePath);
    }
  }

  Future<void> _clearPendingAttachment() async {
    final oldVoicePath = _pendingAttachmentType == 'voice'
        ? _pendingAttachmentFile?.path
        : null;
    setState(() {
      _pendingAttachmentFile = null;
      _pendingAttachmentType = null;
      _pendingAttachmentName = null;
      _activeVoiceKey = null;
    });
    try {
      await _voicePlayer.stop();
    } catch (_) {}
    if (oldVoicePath != null && oldVoicePath.trim().isNotEmpty) {
      await _deleteLocalFile(oldVoicePath);
    }
  }

  Future<void> _togglePendingVoicePlayback() async {
    final file = _pendingAttachmentFile;
    if (_pendingAttachmentType != 'voice' || file == null) return;
    final key = 'pending:${file.path}';
    try {
      if (_activeVoiceKey == key && _voicePlayer.playing) {
        await _voicePlayer.pause();
        if (!mounted) return;
        setState(() => _activeVoiceKey = null);
        return;
      }
      if (_activeVoiceKey != key) {
        await _voicePlayer.setFilePath(file.path);
      }
      await _voicePlayer.play();
      if (!mounted) return;
      setState(() => _activeVoiceKey = key);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play voice note: $e')));
    }
  }

  Future<void> _toggleMessageVoicePlayback(
    CoachSupportChatMessage message,
  ) async {
    final voiceUrl = (message.attachmentUrl ?? '').trim();
    if (voiceUrl.isEmpty) return;
    final key = 'message:${message.id}';
    try {
      if (_activeVoiceKey == key && _voicePlayer.playing) {
        await _voicePlayer.pause();
        if (!mounted) return;
        setState(() => _activeVoiceKey = null);
        return;
      }
      if (_activeVoiceKey != key) {
        final localPath = await VoiceNoteAudioService.prepareLocalVoiceNoteFile(
          voiceUrl,
        );
        await _voicePlayer.setFilePath(localPath);
      }
      await _voicePlayer.play();
      if (!mounted) return;
      setState(() => _activeVoiceKey = key);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play voice note: $e')));
    }
  }

  Future<void> _openImageAttachment(CoachSupportChatMessage message) async {
    final url = (message.attachmentUrl ?? '').trim();
    if (url.isEmpty || _openingAttachment) return;
    setState(() => _openingAttachment = true);
    try {
      final localPath =
          await ChatAttachmentFileService.prepareLocalAttachmentFile(
            url,
            suggestedFileName: message.attachmentFilename,
            fallbackExtension: '.jpg',
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(File(localPath), fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open image: $e')));
    } finally {
      if (mounted) {
        setState(() => _openingAttachment = false);
      }
    }
  }

  Future<void> _openDocumentAttachment(CoachSupportChatMessage message) async {
    final url = (message.attachmentUrl ?? '').trim();
    if (url.isEmpty || _openingAttachment) return;
    setState(() => _openingAttachment = true);
    try {
      final localPath =
          await ChatAttachmentFileService.prepareLocalAttachmentFile(
            url,
            suggestedFileName: message.attachmentFilename,
            fallbackExtension: '.pdf',
          );
      final opened = await launchUrl(
        Uri.file(localPath),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Could not open downloaded document.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open document: $e')));
    } finally {
      if (mounted) {
        setState(() => _openingAttachment = false);
      }
    }
  }

  Future<void> _openVideoAttachment(CoachSupportChatMessage message) async {
    final url = (message.attachmentUrl ?? '').trim();
    if (url.isEmpty || _openingAttachment) return;
    setState(() => _openingAttachment = true);
    try {
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!opened) {
        throw Exception('Could not open video.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open video: $e')));
    } finally {
      if (mounted) {
        setState(() => _openingAttachment = false);
      }
    }
  }

  Future<void> _onMessageLongPress(CoachSupportChatMessage message) async {
    final key = _messageKeyFor(message.id);
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 0.32,
      );
    }
    if (!mounted) return;
    setState(() => _focusedMessageId = message.id);

    final isOwn = message.isFromClient;
    final canReport =
        !isOwn &&
        message.senderUserId != null &&
        (message.senderRole == 'coach' || message.senderRole == 'client');

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.copy_all_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Copy',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(sheetContext).pop('copy'),
              ),
              if (canReport)
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('report'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.messageText));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message copied.')));
    } else if (action == 'report' && canReport) {
      await _reportMessage(message);
    }

    if (mounted) {
      setState(() => _focusedMessageId = null);
    }
  }

  Future<void> _loadChat() async {
    setState(() {
      _loading = true;
      _loadingThread = true;
      _error = null;
    });

    try {
      final threads = await CoachSupportChatService.fetchClientCoachThreads();
      if (!mounted) return;

      int? selectedCoachUserId = _selectedCoachUserId;
      if (threads.isEmpty) {
        setState(() {
          _coachThreads = const <CoachSupportChatThreadSummary>[];
          _selectedCoachUserId = null;
          _chatState = null;
          _loading = false;
          _loadingThread = false;
          _error = null;
        });
        return;
      }

      final hasExistingSelection =
          selectedCoachUserId != null &&
          threads.any((entry) => entry.coachUserId == selectedCoachUserId);
      if (!hasExistingSelection) {
        selectedCoachUserId = threads.first.coachUserId;
      }

      final state = await CoachSupportChatService.fetchClientThreadWithCoach(
        coachUserId: selectedCoachUserId,
      );
      if (!mounted) return;
      setState(() {
        _coachThreads = threads;
        _selectedCoachUserId = selectedCoachUserId;
        _chatState = state;
        _loading = false;
        _loadingThread = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingThread = false;
        _chatState = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _selectCoachThread(int coachUserId) async {
    if (_loadingThread || _selectedCoachUserId == coachUserId) return;
    setState(() {
      _selectedCoachUserId = coachUserId;
      _loadingThread = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.fetchClientThreadWithCoach(
        coachUserId: coachUserId,
      );
      if (!mounted) return;
      setState(() {
        _chatState = state;
        _loadingThread = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingThread = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error ?? 'Failed to open chat')));
    }
  }

  Future<void> _sendMessage() async {
    if (_sending || _isRecordingVoice) return;
    final text = _messageController.text.trim();
    final attachment = _pendingAttachmentFile;
    final attachmentType = (_pendingAttachmentType ?? '').trim().toLowerCase();
    if (text.isEmpty && attachment == null) return;
    final coachUserId = _selectedCoachUserId;
    if (coachUserId == null || coachUserId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a coach first.')));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.sendClientMessage(
        text: text.isEmpty ? null : text,
        messageType: attachment == null ? null : attachmentType,
        attachment: attachment,
        coachUserId: coachUserId,
      );
      if (!mounted) return;
      final oldVoicePath = _pendingAttachmentType == 'voice'
          ? _pendingAttachmentFile?.path
          : null;
      setState(() {
        _chatState = state;
        _sending = false;
        _messageController.clear();
        _pendingAttachmentFile = null;
        _pendingAttachmentType = null;
        _pendingAttachmentName = null;
        _activeVoiceKey = null;
      });
      if (oldVoicePath != null && oldVoicePath.trim().isNotEmpty) {
        await _deleteLocalFile(oldVoicePath);
      }
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

  String _formatBytes(int? value) {
    if (value == null || value <= 0) return '--';
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  Widget _buildCoachSelector() {
    if (_coachThreads.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _coachThreads.map((thread) {
          final selected = thread.coachUserId == _selectedCoachUserId;
          final label = _firstNameOnly(thread.coachName);
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => _selectCoachThread(thread.coachUserId),
            label: Text(label),
            selectedColor: AppColors.accent.withValues(alpha: 0.28),
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.65)
                  : Colors.white12,
            ),
            showCheckmark: false,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSupportHeader(CoachSupportChatState? state) {
    final thread = state?.thread;
    final coachName = thread?.coachName.trim() ?? '';
    final coachFirstName = _firstNameOnly(coachName);
    final coachAvatarUrl = _normalizeAvatarUrl(thread?.coachAvatarUrl);
    final supportsText = state?.supportsText ?? true;
    final supportsImage = state?.supportsImage ?? false;
    final supportsVideo = state?.supportsVideo ?? false;
    final supportsVoice = state?.supportsVoice ?? false;
    final supportsDocument = state?.supportsDocument ?? false;
    final sla = state?.sla;

    final chips = <Widget>[
      _SupportChip(
        label: supportsText ? 'Text: On' : 'Text: Off',
        color: supportsText ? Colors.greenAccent : Colors.white54,
      ),
      _SupportChip(
        label: supportsImage ? 'Image: On' : 'Image: Off',
        color: supportsImage ? Colors.greenAccent : Colors.white54,
      ),
      _SupportChip(
        label: supportsVideo ? 'Video: On' : 'Video: Off',
        color: supportsVideo ? Colors.greenAccent : Colors.white54,
      ),
      _SupportChip(
        label: supportsVoice ? 'Voice: On' : 'Voice: Off',
        color: supportsVoice ? Colors.greenAccent : Colors.white54,
      ),
      _SupportChip(
        label: supportsDocument ? 'Docs: On' : 'Docs: Off',
        color: supportsDocument ? Colors.greenAccent : Colors.white54,
      ),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white10,
                foregroundImage: coachAvatarUrl != null
                    ? NetworkImage(coachAvatarUrl)
                    : null,
                child: coachAvatarUrl == null
                    ? Text(
                        coachFirstName.isEmpty
                            ? 'C'
                            : coachFirstName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
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
          if (sla != null) ...[
            const SizedBox(height: 8),
            Text(
              _buildSlaLine(sla),
              style: TextStyle(
                color: sla.breached ? Colors.orangeAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Target response window: ${sla.targetWindowHoursMin}-${sla.targetWindowHoursMax} hours',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CoachSupportChatMessage message) {
    final isClient = message.isFromClient;
    final bubbleColor = isClient
        ? AppColors.accent.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = isClient
        ? AppColors.accent.withValues(alpha: 0.6)
        : Colors.white10;
    final isFocused = _focusedMessageId == message.id;
    final focusColor = Colors.orangeAccent.withValues(alpha: 0.75);

    return Align(
      alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        key: _messageKeyFor(message.id),
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _onMessageLongPress(message),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFocused ? focusColor : borderColor),
          ),
          child: Column(
            crossAxisAlignment: isClient
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.messageText.isNotEmpty)
                Text(
                  message.messageText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              if (message.hasAttachment && message.isImage) ...[
                if (message.messageText.isNotEmpty) const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openImageAttachment(message),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      message.attachmentUrl!,
                      width: 210,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Container(
                          width: 210,
                          height: 150,
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else if (message.hasAttachment && message.isVideo) ...[
                if (message.messageText.isNotEmpty) const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openVideoAttachment(message),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.attachmentFilename?.trim().isNotEmpty ==
                                    true
                                ? message.attachmentFilename!
                                : 'Video attachment',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (message.hasAttachment && message.isVoice) ...[
                if (message.messageText.isNotEmpty) const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggleMessageVoicePlayback(message),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _activeVoiceKey == 'message:${message.id}' &&
                                  _voicePlayer.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.attachmentFilename?.trim().isNotEmpty ==
                                    true
                                ? message.attachmentFilename!
                                : 'Voice note',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (message.hasAttachment && message.isDocument) ...[
                if (message.messageText.isNotEmpty) const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openDocumentAttachment(message),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.attachmentFilename?.trim().isNotEmpty ==
                                        true
                                    ? message.attachmentFilename!
                                    : 'Document',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatBytes(message.attachmentSizeBytes),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                _formatDateTime(message.createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
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
    final noCoach = _coachThreads.isEmpty || _selectedCoachUserId == null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildSupportHeader(state),
        _buildCoachSelector(),
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
        if (!noCoach && _loadingThread)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (!noCoach &&
            !_loadingThread &&
            state != null &&
            state.messages.isEmpty)
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
        if (!noCoach && !_loadingThread && state != null)
          ...state.messages.map(_buildMessageBubble),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildComposer() {
    final state = _chatState;
    final disabled =
        _loading ||
        _loadingThread ||
        _sending ||
        state == null ||
        state.thread == null ||
        !state.supportsText ||
        _selectedCoachUserId == null;
    final sendDisabled =
        disabled ||
        _sending ||
        _isRecordingVoice ||
        (_messageController.text.trim().isEmpty &&
            _pendingAttachmentFile == null);
    final hasPending = _pendingAttachmentFile != null;
    final pendingType = (_pendingAttachmentType ?? '').trim().toLowerCase();

    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.black,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPending)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(
                      pendingType == 'image'
                          ? Icons.image_outlined
                          : pendingType == 'video'
                          ? Icons.videocam_outlined
                          : pendingType == 'voice'
                          ? Icons.mic_none_rounded
                          : Icons.description_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_pendingAttachmentName ?? 'Attachment').trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pendingType == 'voice')
                      IconButton(
                        onPressed: _sending
                            ? null
                            : _togglePendingVoicePlayback,
                        iconSize: 20,
                        color: Colors.white70,
                        splashRadius: 18,
                        icon: Icon(
                          _activeVoiceKey ==
                                      'pending:${_pendingAttachmentFile?.path}' &&
                                  _voicePlayer.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                      ),
                    IconButton(
                      onPressed: _sending ? null : _clearPendingAttachment,
                      iconSize: 18,
                      color: Colors.orangeAccent,
                      splashRadius: 18,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            if (_isRecordingVoice)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Recording voice... release to keep',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: disabled || _isRecordingVoice
                      ? null
                      : _pickAttachment,
                  tooltip: 'Attach',
                  icon: const Icon(Icons.attach_file_rounded),
                  color: Colors.white70,
                ),
                GestureDetector(
                  onLongPressStart: disabled
                      ? null
                      : (_) => _startVoiceRecording(),
                  onLongPressEnd: disabled
                      ? null
                      : (_) => _finishVoiceRecording(),
                  onLongPressCancel: disabled
                      ? null
                      : () => _finishVoiceRecording(discard: true),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isRecordingVoice
                          ? Colors.redAccent.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: _isRecordingVoice
                            ? Colors.redAccent.withValues(alpha: 0.7)
                            : Colors.white10,
                      ),
                    ),
                    child: Icon(
                      _isRecordingVoice ? Icons.mic : Icons.mic_none_rounded,
                      color: _isRecordingVoice
                          ? Colors.redAccent
                          : Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
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
                  onPressed: sendDisabled ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(56, 44),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      : const Text('🚀', style: TextStyle(fontSize: 18)),
                ),
              ],
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
