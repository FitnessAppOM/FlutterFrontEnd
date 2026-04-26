import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatVideoPreviewTile extends StatefulWidget {
  const ChatVideoPreviewTile({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.onTap,
  });

  final String videoUrl;
  final String title;
  final VoidCallback onTap;

  @override
  State<ChatVideoPreviewTile> createState() => _ChatVideoPreviewTileState();
}

class _ChatVideoPreviewTileState extends State<ChatVideoPreviewTile> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant ChatVideoPreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _loading = true;
      _failed = false;
      _initController();
    }
  }

  Future<void> _initController() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _disposeController() async {
    final current = _controller;
    _controller = null;
    if (current != null) {
      await current.dispose();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty ? 'Video' : widget.title.trim();
    final controller = _controller;
    final initialized = controller != null && controller.value.isInitialized;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onTap,
      child: Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (initialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : Icon(
                          _failed
                              ? Icons.videocam_off_outlined
                              : Icons.videocam_outlined,
                          color: Colors.white70,
                          size: 26,
                        ),
                ),
              ),
            Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
