import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key, required this.url, this.title = 'Document'});

  final String url;
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
    _download();
  }

  Future<void> _download() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download document (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last.split('?').first;
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
      appBar: AppBar(
        backgroundColor: TaqaUiColors.unnamedColor1c1d17,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          widget.title,
          style: TaqaUiStyles.pageTitle.copyWith(color: TaqaUiColors.white),
        ),
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
