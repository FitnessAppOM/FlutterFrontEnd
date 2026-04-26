import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class DietDocumentFileService {
  static Uri? resolveUri(String? rawUrl) {
    final raw = (rawUrl ?? '').trim();
    if (raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    final base = ApiConfig.baseUrl.trim();
    if (base.isEmpty) return null;
    final baseUri = Uri.tryParse(base.endsWith('/') ? base : '$base/');
    if (baseUri == null) return null;
    return baseUri.resolve(raw.startsWith('/') ? raw.substring(1) : raw);
  }

  static Future<String> prepareLocalDietDocumentFile(
    String rawUrl, {
    String? suggestedFileName,
  }) async {
    final uri = resolveUri(rawUrl);
    if (uri == null) {
      throw Exception('Invalid document URL.');
    }

    final cacheDir = Directory(
      '${(await getTemporaryDirectory()).path}/diet_documents',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final digest = sha1.convert(utf8.encode(uri.toString())).toString();
    var extension = _guessDocumentExtension(
      uri: uri,
      suggestedFileName: suggestedFileName,
    );
    var file = File('${cacheDir.path}/$digest$extension');
    if (await file.exists()) {
      final size = await file.length();
      if (size > 0) return file.path;
      try {
        await file.delete();
      } catch (_) {}
    }

    final headers = await _headersFor(uri);
    final response = await http.get(uri, headers: headers);
    await AccountStorage.handleAuthStatus(
      response.statusCode,
      responseBody: response.body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to download document (${response.statusCode}).');
    }

    extension = _guessDocumentExtension(
      uri: uri,
      suggestedFileName: suggestedFileName,
      contentType: response.headers['content-type'],
    );
    file = File('${cacheDir.path}/$digest$extension');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  static Future<Map<String, String>> _headersFor(Uri targetUri) async {
    final headers = <String, String>{};
    final targetHost = targetUri.host.toLowerCase();
    final apiHost = Uri.tryParse(ApiConfig.baseUrl)?.host.toLowerCase();
    if (apiHost != null && apiHost.isNotEmpty && targetHost == apiHost) {
      headers.addAll(await AccountStorage.getAuthHeaders());
    }
    return headers;
  }

  static String _guessDocumentExtension({
    required Uri uri,
    String? suggestedFileName,
    String? contentType,
  }) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf')) return '.pdf';
    if (path.endsWith('.doc')) return '.doc';
    if (path.endsWith('.docx')) return '.docx';
    if (path.endsWith('.txt')) return '.txt';
    if (path.endsWith('.rtf')) return '.rtf';

    final filename = (suggestedFileName ?? '').trim().toLowerCase();
    if (filename.endsWith('.pdf')) return '.pdf';
    if (filename.endsWith('.doc')) return '.doc';
    if (filename.endsWith('.docx')) return '.docx';
    if (filename.endsWith('.txt')) return '.txt';
    if (filename.endsWith('.rtf')) return '.rtf';

    final normalizedContentType = (contentType ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (normalizedContentType == 'application/pdf') return '.pdf';
    if (normalizedContentType == 'application/msword') return '.doc';
    if (normalizedContentType ==
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return '.docx';
    }
    if (normalizedContentType == 'text/plain') return '.txt';
    if (normalizedContentType == 'application/rtf' ||
        normalizedContentType == 'text/rtf') {
      return '.rtf';
    }
    return '.pdf';
  }
}
