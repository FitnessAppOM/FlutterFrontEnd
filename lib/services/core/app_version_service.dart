import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';

class AppVersionInfo {
  final String? minVersion;
  final String? latestVersion;
  final bool forceUpdate;
  final String? message;

  AppVersionInfo({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.message,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      minVersion: (json['min_version'] ?? json['minVersion'])?.toString(),
      latestVersion: (json['latest_version'] ?? json['latestVersion'])?.toString(),
      forceUpdate: json['force_update'] == true || json['forceUpdate'] == true,
      message: json['message']?.toString(),
    );
  }
}

class AppVersionService {
  static Future<AppVersionInfo?> fetchRemoteVersion() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/app/version');
      final res = await http.get(url);
      if (res.statusCode != 200 || res.body.isEmpty) return null;
      final data = json.decode(res.body);
      if (data is Map<String, dynamic>) {
        return AppVersionInfo.fromJson(data);
      }
      if (data is Map) {
        return AppVersionInfo.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
