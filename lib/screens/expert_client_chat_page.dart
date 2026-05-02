import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/base_url.dart';
import '../services/coach/chat_attachment_file_service.dart';
import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/voice_note_audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coach/chat_video_player_page.dart';
import '../widgets/coach/chat_video_preview_tile.dart';

class ExpertClientChatPage extends StatefulWidget {
  const ExpertClientChatPage({
    super.key,
    required this.clientUserId,
    required this.clientName,
  });

  final int clientUserId;
  final String clientName;

  @override
  State<ExpertClientChatPage> createState() => _ExpertClientChatPageState();
}

class _ExpertClientChatPageState extends State<ExpertClientChatPage> {
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  bool _loading = true;
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
  int? _focusedMessageId;
  Timer? _ticker;
  StreamSubscription<PlayerState>? _voicePlayerSub;

  String _voiceStartErrorMessage(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    final isBusySession =
        normalized.contains('osstatus error 561017449') ||
        normalized.contains('setcategory') ||
        normalized.contains('session activation failed') ||
        normalized.contains('failed to start recording');
    if (isBusySession) {
      return 'Microphone is busy (often during a phone/FaceTime/VoIP call). End the call or close other mic apps, then try again.';
    }
    return 'Could not start recording. Please try again.';
  }

  bool _isVoiceKeyActivelyPlaying(String key) {
    if (_activeVoiceKey != key) return false;
    if (!_voicePlayer.playing) return false;
    return _voicePlayer.processingState != ProcessingState.completed;
  }

  @override
  void initState() {
    super.initState();
    _loadChat();
    _voicePlayerSub = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed ||
          (state.processingState == ProcessingState.idle && !state.playing)) {
        setState(() => _activeVoiceKey = null);
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
    _chatScrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false, int retries = 3}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_chatScrollController.hasClients) {
        if (retries > 0) {
          Future<void>.delayed(
            const Duration(milliseconds: 16),
            () => _scrollToBottom(animated: animated, retries: retries - 1),
          );
        }
        return;
      }
      final target = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.fetchCoachClientThread(
        clientUserId: widget.clientUserId,
      );
      if (!mounted) return;
      setState(() {
        _chatState = state;
        _loading = false;
      });
      _scrollToBottom();
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
    if (_sending || _isRecordingVoice) return;
    final text = _messageController.text.trim();
    final attachment = _pendingAttachmentFile;
    final attachmentType = (_pendingAttachmentType ?? '').trim().toLowerCase();
    if (text.isEmpty && attachment == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final state = await CoachSupportChatService.sendCoachMessage(
        clientUserId: widget.clientUserId,
        text: text.isEmpty ? null : text,
        messageType: attachment == null ? null : attachmentType,
        attachment: attachment,
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
      _scrollToBottom(animated: true);
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

  String _firstNameOnly(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'Client';
    final parts = normalized
        .split(RegExp(r'\\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Client';
    return parts.first;
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

  Future<void> _pickAttachment(List<String> allowedExtensions) async {
    if (_sending || _isRecordingVoice) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
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

  Future<void> _showAttachmentOptions() async {
    if (_sending || _isRecordingVoice) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.perm_media_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Photo or video',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Upload an image or video',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () => Navigator.of(sheetContext).pop('media'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Document',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Upload a file like PDF or DOCX',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () => Navigator.of(sheetContext).pop('document'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'media') {
      await _pickMediaFromGallery();
      return;
    }
    if (choice == 'document') {
      await _pickAttachment(const ['pdf', 'doc', 'docx', 'txt', 'rtf']);
    }
  }

  Future<void> _pickMediaFromGallery() async {
    if (_sending || _isRecordingVoice) return;
    try {
      final picked = await _imagePicker.pickMedia();
      if (!mounted || picked == null) return;

      final ext = picked.path.trim().isEmpty
          ? ''
          : '.${picked.path.split('.').last.toLowerCase()}';
      final type = _inferAttachmentType(extension: ext);
      if (type == null || (type != 'image' && type != 'video')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported media type.')),
        );
        return;
      }

      final previousVoicePath = _pendingAttachmentType == 'voice'
          ? _pendingAttachmentFile?.path
          : null;
      setState(() {
        _pendingAttachmentFile = File(picked.path);
        _pendingAttachmentType = type;
        _pendingAttachmentName = picked.name.trim().isEmpty
            ? 'attachment$ext'
            : picked.name.trim();
        _activeVoiceKey = null;
      });
      if (previousVoicePath != null && previousVoicePath.trim().isNotEmpty) {
        await _deleteLocalFile(previousVoicePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open gallery: $e')));
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
      String nextPath() =>
          '${tempDir.path}/support_chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final config = const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        iosConfig: IosRecordConfig(
          categoryOptions: <IosAudioCategoryOption>[
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
          ],
        ),
        androidConfig: AndroidRecordConfig(
          useLegacy: true,
          manageBluetooth: false,
          audioManagerMode: AudioManagerMode.modeInCommunication,
        ),
      );

      Future<void> startOnce(String path) async {
        try {
          await _voicePlayer.stop();
        } catch (_) {}
        try {
          await _audioRecorder.stop();
        } catch (_) {}
        if (Platform.isIOS || Platform.isAndroid) {
          await Future<void>.delayed(const Duration(milliseconds: 140));
        }
        await _audioRecorder.start(config, path: path);
      }

      var path = nextPath();
      try {
        await startOnce(path);
      } catch (firstError) {
        final text = firstError.toString().toLowerCase();
        final shouldRetry =
            text.contains('setactive') ||
            text.contains('session activation') ||
            text.contains('failed to start recording') ||
            text.contains('platformexception(record');
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 260));
        path = nextPath();
        await startOnce(path);
      }
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _recordingVoicePath = path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_voiceStartErrorMessage(e))));
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
        final remoteUri = ChatAttachmentFileService.resolveUri(url);
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
      final localPath =
          await ChatAttachmentFileService.prepareLocalAttachmentFile(
            url,
            suggestedFileName: message.attachmentFilename,
            fallbackExtension: '.mp4',
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatVideoPlayerPage(
            videoPath: localPath,
            title: message.attachmentFilename,
          ),
        ),
      );
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

    final isOwn = message.isFromCoach;
    final canReport =
        !isOwn &&
        message.senderUserId != null &&
        (message.senderRole == 'client' || message.senderRole == 'coach');

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

  String _buildSlaLine(CoachSupportChatSla sla) {
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
      return 'Thread active.';
    }
    return 'Expected response within: ${sla.targetWindowHoursMin}-${sla.targetWindowHoursMax}h';
  }

  Widget _buildHeader(CoachSupportChatState state) {
    final thread = state.thread;
    final clientName = _firstNameOnly(thread?.clientName ?? widget.clientName);
    final clientAvatarUrl = _normalizeAvatarUrl(thread?.clientAvatarUrl);
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
                foregroundImage: clientAvatarUrl != null
                    ? NetworkImage(clientAvatarUrl)
                    : null,
                child: clientAvatarUrl == null
                    ? Text(
                        clientName.isEmpty
                            ? 'C'
                            : clientName.substring(0, 1).toUpperCase(),
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
                  'Support chat',
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
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CoachSupportChatMessage message) {
    final isCoach = message.isFromCoach;
    final isRedHighlight = message.isHighlightedRed;
    final bubbleColor = isRedHighlight
        ? Colors.redAccent.withValues(alpha: 0.16)
        : (isCoach
              ? AppColors.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06));
    final borderColor = isRedHighlight
        ? Colors.redAccent.withValues(alpha: 0.8)
        : (isCoach ? AppColors.accent.withValues(alpha: 0.6) : Colors.white10);
    final isFocused = _focusedMessageId == message.id;
    final focusColor = Colors.orangeAccent.withValues(alpha: 0.75);

    return Align(
      alignment: isCoach ? Alignment.centerRight : Alignment.centerLeft,
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
            crossAxisAlignment: isCoach
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
                ChatVideoPreviewTile(
                  videoUrl: message.attachmentUrl!,
                  title: message.attachmentFilename ?? 'Video',
                  onTap: () => _openVideoAttachment(message),
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
                          _isVoiceKeyActivelyPlaying('message:${message.id}')
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
    if (state == null) {
      return ListView(
        controller: _chatScrollController,
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

    return ListView(
      controller: _chatScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeader(state),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        if (messages.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'No messages yet. Send your first message.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ...messages.map(_buildMessageBubble),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildComposer() {
    final disabled = _loading || _sending || _chatState?.thread == null;
    final sendDisabled =
        disabled ||
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
                          _isVoiceKeyActivelyPlaying(
                                'pending:${_pendingAttachmentFile?.path}',
                              )
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
            Row(
              children: [
                IconButton(
                  onPressed: disabled || _isRecordingVoice
                      ? null
                      : _showAttachmentOptions,
                  tooltip: 'Add media',
                  icon: const Icon(Icons.add_rounded),
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
                  child: _isRecordingVoice
                      ? Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Recording voice... release to keep',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextField(
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
                                : 'Write a message',
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
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                              ),
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
                      : const Icon(Icons.send_rounded, size: 18),
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
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Support Chat'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadChat,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(onRefresh: _loadChat, child: _buildBody()),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}
