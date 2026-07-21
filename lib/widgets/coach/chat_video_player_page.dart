import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/user_friendly_error.dart';
import '../../theme/app_theme.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';

class ChatVideoPlayerPage extends StatefulWidget {
  const ChatVideoPlayerPage({super.key, required this.videoPath, this.title});

  final String videoPath;
  final String? title;

  @override
  State<ChatVideoPlayerPage> createState() => _ChatVideoPlayerPageState();
}

class _ChatVideoPlayerPageState extends State<ChatVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.title ?? '').trim();
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: TaqaPageAppBar(
        title: title.isEmpty ? 'Video' : title,
        backgroundColor: AppColors.black,
        titleColor: Colors.white,
      ),
      body: Center(
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not open video.\n$_error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )
            : controller == null || !controller.value.isInitialized
            ? const Text(
                'Could not open video.',
                style: TextStyle(color: Colors.white70),
              )
            : GestureDetector(
                onTap: () async {
                  if (controller.value.isPlaying) {
                    await controller.pause();
                  } else {
                    await controller.play();
                  }
                  if (!mounted) return;
                  setState(() {});
                },
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio <= 0
                              ? 16 / 9
                              : controller.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(controller),
                              if (!controller.value.isPlaying)
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        colors: VideoProgressColors(
                          playedColor: AppColors.accent,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white10,
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
