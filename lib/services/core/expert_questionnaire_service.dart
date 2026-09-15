import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ExpertDocumentUpload {
  const ExpertDocumentUpload({
    required this.documentId,
    required this.reference,
    required this.status,
    this.url,
  });

  final String documentId;
  final String reference;
  final String status;
  final String? url;

  bool get isClean => status == "clean";

  factory ExpertDocumentUpload.fromJson(Map<String, dynamic> data) {
    return ExpertDocumentUpload(
      documentId: (data["document_id"] ?? "").toString(),
      reference: (data["reference"] ?? data["url"] ?? "").toString(),
      status: (data["status"] ?? "pending").toString(),
      url: data["url"]?.toString(),
    );
  }
}

class ExpertQuestionnaireApi {
  static const maxUploadBytes = 5 * 1024 * 1024;

  static Future<void> submit(Map<String, dynamic> data) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/expert-questionnaire/submit");
    final res = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            ...await AccountStorage.getAuthHeaders(),
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 30));
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) return;
    String msg = "Failed to submit questionnaire";
    try {
      final body = jsonDecode(res.body);
      msg = body["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<ExpertDocumentUpload> upload(
    String kind,
    String filePath,
  ) async {
    final size = await File(filePath).length();
    if (size == 0) throw Exception("The selected file is empty.");
    if (size > maxUploadBytes) {
      throw Exception("File must be 5MB or less.");
    }
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/expert-questionnaire/upload/$kind",
    );
    final request = http.MultipartRequest("POST", url);
    request.headers.addAll(await AccountStorage.getAuthHeaders());
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    // Closing the client also aborts the connection when the deadline expires.
    final client = http.Client();
    late http.Response res;
    try {
      res = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 90));
    } finally {
      client.close();
    }
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final upload = ExpertDocumentUpload.fromJson(data);
      if (upload.documentId.isEmpty || upload.reference.isEmpty) {
        throw Exception("Invalid document upload response");
      }
      return upload;
    }
    String msg = "Failed to upload file";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<ExpertDocumentUpload> getUploadStatus(String documentId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/expert-questionnaire/upload/$documentId/status",
    );
    final client = http.Client();
    late http.Response res;
    try {
      res = await client
          .get(url, headers: await AccountStorage.getAuthHeaders())
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close();
    }
    await AccountStorage.handle401(res.statusCode);
    if (res.statusCode == 200) {
      return ExpertDocumentUpload.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    String msg = "Failed to check document security scan";
    try {
      final data = jsonDecode(res.body);
      msg = data["detail"]?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }
}
