import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class VoiceNoteAudioService {
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

  static Future<String> prepareLocalVoiceNoteFile(String rawUrl) async {
    final uri = resolveUri(rawUrl);
    if (uri == null) {
      throw Exception('Invalid voice note URL.');
    }

    final cacheDir = Directory(
      '${(await getTemporaryDirectory()).path}/voice_notes',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final digest = sha1.convert(utf8.encode(uri.toString())).toString();
    final extension = _guessAudioExtension(uri);
    final file = File('${cacheDir.path}/$digest$extension');
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
        'Failed to download voice note (${response.statusCode}).',
      );
    }

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

  static String _guessAudioExtension(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.aac')) return '.aac';
    if (path.endsWith('.mp3')) return '.mp3';
    if (path.endsWith('.wav')) return '.wav';
    if (path.endsWith('.ogg')) return '.ogg';
    if (path.endsWith('.webm')) return '.webm';
    return '.m4a';
  }
}
