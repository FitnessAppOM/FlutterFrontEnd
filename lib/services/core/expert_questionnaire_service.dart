import 'dart:convert';
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
  static Future<void> submit(Map<String, dynamic> data) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/expert-questionnaire/submit");
    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        ...await AccountStorage.getAuthHeaders(),
      },
      body: jsonEncode(data),
    );
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
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/expert-questionnaire/upload/$kind",
    );
    final request = http.MultipartRequest("POST", url);
    request.headers.addAll(await AccountStorage.getAuthHeaders());
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
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
    final res = await http.get(
      url,
      headers: await AccountStorage.getAuthHeaders(),
    );
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
