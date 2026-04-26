import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ChatAttachmentFileService {
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

  static Future<String> prepareLocalAttachmentFile(
    String rawUrl, {
    String? suggestedFileName,
    String? fallbackExtension,
  }) async {
    final uri = resolveUri(rawUrl);
    if (uri == null) {
      throw Exception('Invalid attachment URL.');
    }

    final cacheDir = Directory(
      '${(await getTemporaryDirectory()).path}/chat_attachments',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    var extension = _guessExtension(
      uri: uri,
      suggestedFileName: suggestedFileName,
      fallbackExtension: fallbackExtension,
    );
    final digest = sha1.convert(utf8.encode(uri.toString())).toString();
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
      throw Exception(
        'Failed to download attachment (${response.statusCode}).',
      );
    }

    extension = _guessExtension(
      uri: uri,
      suggestedFileName: suggestedFileName,
      contentType: response.headers['content-type'],
      fallbackExtension: fallbackExtension,
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

  static String _guessExtension({
    required Uri uri,
    String? suggestedFileName,
    String? contentType,
    String? fallbackExtension,
  }) {
    final path = uri.path.toLowerCase();
    final name = (suggestedFileName ?? '').trim().toLowerCase();
    final ctype = (contentType ?? '').split(';').first.trim().toLowerCase();

    String? findKnownExt(String source) {
      const known = <String>[
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.gif',
        '.mp4',
        '.mov',
        '.m4v',
        '.webm',
        '.aac',
        '.m4a',
        '.mp3',
        '.wav',
        '.ogg',
        '.pdf',
        '.doc',
        '.docx',
        '.txt',
        '.rtf',
      ];
      for (final ext in known) {
        if (source.endsWith(ext)) return ext;
      }
      return null;
    }

    final fromPath = findKnownExt(path);
    if (fromPath != null) return fromPath;
    final fromName = findKnownExt(name);
    if (fromName != null) return fromName;

    const mimeMap = <String, String>{
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/gif': '.gif',
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
      'video/x-m4v': '.m4v',
      'video/webm': '.webm',
      'audio/aac': '.aac',
      'audio/mp4': '.m4a',
      'audio/m4a': '.m4a',
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/wav': '.wav',
      'audio/x-wav': '.wav',
      'audio/ogg': '.ogg',
      'audio/webm': '.webm',
      'application/pdf': '.pdf',
      'application/msword': '.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          '.docx',
      'text/plain': '.txt',
      'application/rtf': '.rtf',
      'text/rtf': '.rtf',
    };
    final fromMime = mimeMap[ctype];
    if (fromMime != null) return fromMime;

    final fallback = (fallbackExtension ?? '').trim();
    if (fallback.isNotEmpty) {
      return fallback.startsWith('.') ? fallback : '.$fallback';
    }
    return '.bin';
  }
}
