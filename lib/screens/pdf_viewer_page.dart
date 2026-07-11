import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_back_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({
    super.key,
    this.url,
    this.localPath,
    this.title = 'Document',
  }) : assert(
         url != null || localPath != null,
         'PdfViewerPage needs either a remote url to download or an '
         'already-downloaded localPath to open.',
       );

  /// Remote url to download and cache before displaying. Ignored when
  /// [localPath] is provided.
  final String? url;

  /// A file already downloaded to disk (e.g. via an authenticated request
  /// the caller made itself) — skips the plain, unauthenticated download
  /// this page would otherwise do from [url].
  final String? localPath;

  final String title;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.localPath != null) {
      _localPath = widget.localPath;
    } else {
      _download();
    }
  }

  Future<void> _download() async {
    try {
      final url = widget.url!;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download document (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final fileName = url.split('/').last.split('?').first;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      setState(() => _localPath = file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColor1c1d17,
      appBar: TaqaPageAppBar(
        title: widget.title,
        backgroundColor: TaqaUiColors.unnamedColor1c1d17,
        titleColor: TaqaUiColors.white,
        leading: const TaqaBackButton(color: TaqaUiColors.white),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: TaqaUiScale.insetsLTRB(24, 0, 24, 0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              color: TaqaUiColors.white,
            ),
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(
        child: CircularProgressIndicator(color: TaqaUiColors.lime),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onError: (error) {
        setState(() => _error = error.toString());
      },
      onRender: (pages) {},
    );
  }
}
