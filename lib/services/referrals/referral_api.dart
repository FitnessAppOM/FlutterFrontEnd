import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ReferralIdentity {
  const ReferralIdentity({required this.code, required this.shareUrl});

  final String code;
  final String shareUrl;
}

class ReferralApi {
  ReferralApi._();

  static Future<ReferralIdentity> myReferralIdentity() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/community/referrals/me'),
      headers: {
        ...await AccountStorage.getAuthHeaders(),
        'Accept': 'application/json',
      },
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail'] as String?
          : null;
      throw Exception(detail ?? 'Could not load your referral code.');
    }
    return ReferralIdentity(
      code: decoded['referral_code'] as String,
      shareUrl: decoded['share_url'] as String,
    );
  }
}
