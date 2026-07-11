import 'package:flutter/material.dart';

import '../../screens/pdf_viewer_page.dart';

/// Opens a PDF using the app's in-app viewer instead of handing off to an
/// external app, so the user stays inside Taqa. Shared by any screen that
/// links out to a PDF (announcements/news articles, coach-sent diet plan
/// documents, ...).
class PdfOpenService {
  PdfOpenService._();

  static bool isPdfUrl(String? rawUrl, {String? suggestedFileName}) {
    final url = (rawUrl ?? '').trim().toLowerCase();
    final name = (suggestedFileName ?? '').trim().toLowerCase();
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url;
    return path.endsWith('.pdf') || name.endsWith('.pdf');
  }

  static Future<void> openInApp(
    BuildContext context, {
    required String url,
    String title = 'Document',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerPage(url: url, title: title),
      ),
    );
  }

  /// Like [openInApp], but for a file the caller already downloaded itself
  /// (e.g. via an authenticated request) — skips this page re-downloading
  /// it from a plain, unauthenticated request.
  static Future<void> openLocalFile(
    BuildContext context, {
    required String path,
    String title = 'Document',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerPage(localPath: path, title: title),
      ),
    );
  }
}
