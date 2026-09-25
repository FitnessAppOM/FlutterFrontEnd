import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class UniversityServiceException implements Exception {
  const UniversityServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RecognizedUniversity {
  const RecognizedUniversity({
    required this.id,
    required this.name,
    required this.emailDomain,
  });

  final int id;
  final String name;
  final String emailDomain;
}

class StudentVerificationStatus {
  const StudentVerificationStatus({
    required this.verified,
    this.universityId,
    this.universityName,
    this.email,
  });

  final bool verified;
  final int? universityId;
  final String? universityName;
  final String? email;
}

class UniversityService {
  static Future<Map<String, String>> _authHeaders() async => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    ...await AccountStorage.getAuthHeaders(),
  };

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const UniversityServiceException(
        'The university service returned an invalid response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UniversityServiceException(
        decoded['detail']?.toString() ??
            'The university could not be recognized.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  static Future<List<Map<String, dynamic>>> fetchUniversities() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/universities');

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Failed to load universities');
    }

    final List data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<RecognizedUniversity> recognizeEmail(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/student-verification/recognize'),
      headers: await _authHeaders(),
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );
    final data = _decode(response);
    return RecognizedUniversity(
      id: int.parse(data['university_id'].toString()),
      name: data['university_name'].toString(),
      emailDomain: data['email_domain'].toString(),
    );
  }

  static Future<StudentVerificationStatus> fetchVerificationStatus() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/student-verification/status'),
      headers: await _authHeaders(),
    );
    final data = _decode(response);
    final rawUniversityId = data['university_id'];
    return StudentVerificationStatus(
      verified: data['verified'] == true,
      universityId: rawUniversityId == null
          ? null
          : int.tryParse(rawUniversityId.toString()),
      universityName: data['university_name']?.toString(),
      email: data['email']?.toString(),
    );
  }

  static Future<StudentVerificationStatus>
  activateVerifiedStudentStatus() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/student-verification/activate'),
      headers: await _authHeaders(),
    );
    final data = _decode(response);
    return StudentVerificationStatus(
      verified: data['verified'] == true,
      universityId: int.tryParse(data['university_id']?.toString() ?? ''),
      universityName: data['university_name']?.toString(),
      email: data['email']?.toString(),
    );
  }
}
