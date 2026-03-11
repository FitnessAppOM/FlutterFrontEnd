import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../services/share/cardio_share_service.dart';
import '../../../widgets/cardio/cardio_map.dart';
import 'model_a_page.dart';
import 'model_b_page.dart';
import 'model_c_page.dart';

class OtherModelsPage extends StatefulWidget {
  const OtherModelsPage({
    super.key,
    required this.snapshotUrl,
    required this.route,
    required this.durationLabel,
    required this.distanceLabel,
    required this.paceLabel,
    required this.userName,
    required this.dateLabel,
  });

  final String snapshotUrl;
  final List<CardioPoint> route;
  final String durationLabel;
  final String distanceLabel;
  final String paceLabel;
  final String? userName;
  final String dateLabel;

  @override
  State<OtherModelsPage> createState() => _OtherModelsPageState();
}

class _OtherModelsPageState extends State<OtherModelsPage> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _saving = false;
  bool _sharing = false;
  final GlobalKey _modelAKey = GlobalKey();
  final GlobalKey _modelBKey = GlobalKey();
  final GlobalKey _modelCKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureCurrentPage({bool forceBackground = false}) async {
    final key = _index == 0
        ? _modelAKey
        : _index == 1
            ? _modelBKey
            : _modelCKey;
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final bytes = await CardioShareService.capturePng(boundary);
    if (bytes == null) return null;
    // Only Model A gets a solid background by default. Model B/C stay transparent.
    if (_index == 0 || forceBackground) {
      final flattened = await CardioShareService.flattenPngOnBackground(
        bytes,
        const Color(0xFF0B0F1A),
        cornerRadius: 22,
      );
      return flattened ?? bytes;
    }
    return bytes;
  }

  Future<void> _saveCurrentPage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await CardioShareService.ensurePhotoPermission();
      if (!ok) return;
      final output = await _captureCurrentPage(forceBackground: true);
      if (output == null) return;
      await CardioShareService.savePngBytes(output);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareCurrentPage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final output = await _captureCurrentPage(forceBackground: true);
      if (output == null) return;
      await CardioShareService.sharePngBytes(context, output);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareInstagramOnly() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final output = await _captureCurrentPage();
      if (output == null) return;
      final error = await CardioShareService.shareInstagramStickerDetailed(output);
      // Debug only
      // ignore: avoid_print
      print('[IGSticker] result=${error ?? "ok"}');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        elevation: 0,
        title: const Text('Models'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                ModelAPage(
                  snapshotUrl: widget.snapshotUrl,
                  durationLabel: widget.durationLabel,
                  distanceLabel: widget.distanceLabel,
                  paceLabel: widget.paceLabel,
                  captureKey: _modelAKey,
                  userName: widget.userName,
                  dateLabel: widget.dateLabel,
                ),
                ModelBPage(
                  route: widget.route,
                  durationLabel: widget.durationLabel,
                  distanceLabel: widget.distanceLabel,
                  paceLabel: widget.paceLabel,
                  captureKey: _modelBKey,
                  userName: widget.userName,
                  dateLabel: widget.dateLabel,
                ),
                ModelCPage(
                  route: widget.route,
                  durationLabel: widget.durationLabel,
                  distanceLabel: widget.distanceLabel,
                  paceLabel: widget.paceLabel,
                  captureKey: _modelCKey,
                  userName: widget.userName,
                  dateLabel: widget.dateLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PageDots(count: 3, index: _index),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _index == 0
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _sharing ? null : _shareCurrentPage,
                              child: Text(
                                _sharing
                                    ? 'Sharing...'
                                    : 'Share',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _sharing ? null : _shareInstagramOnly,
                              child: const Text('IG Sticker'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveCurrentPage,
                          child: Text(
                            _saving
                                ? 'Saving...'
                                : 'Save to Photos',
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _sharing ? null : _shareCurrentPage,
                              child: Text(
                                _sharing
                                    ? 'Sharing...'
                                    : 'Share',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _sharing ? null : _shareInstagramOnly,
                              child: const Text('IG Sticker'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveCurrentPage,
                          child: Text(
                            _saving
                                ? 'Saving...'
                                : 'Save to Photos',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final dots = List<Widget>.generate(count, (i) {
      final active = i == index;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 16 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(99),
        ),
      );
    });
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots,
    );
  }
}
