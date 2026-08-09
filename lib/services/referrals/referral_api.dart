import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class ReferralApiException implements Exception {
  const ReferralApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ReferralIdentity {
  const ReferralIdentity({required this.code, required this.shareUrl});

  final String code;
  final String shareUrl;
}

class ReferralReward {
  const ReferralReward({
    required this.id,
    required this.type,
    required this.status,
    this.billingPeriod,
    this.platform,
  });

  final int id;
  final String type;
  final String status;
  final String? billingPeriod;
  final String? platform;

  bool get isClaimable => status == 'qualified';

  factory ReferralReward.fromJson(Map<String, dynamic> json) {
    return ReferralReward(
      id: (json['id'] as num).toInt(),
      type: json['reward_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      billingPeriod: json['billing_period'] as String?,
      platform: json['platform'] as String?,
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    required this.identity,
    required this.qualifiedReferralCount,
    required this.claimableCount,
    required this.rewards,
    required this.hasAttribution,
  });

  final ReferralIdentity identity;
  final int qualifiedReferralCount;
  final int claimableCount;
  final List<ReferralReward> rewards;
  final bool hasAttribution;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final rewardJson = json['rewards'];
    return ReferralSummary(
      identity: ReferralIdentity(
        code: json['referral_code'] as String? ?? '',
        shareUrl: json['share_url'] as String? ?? '',
      ),
      qualifiedReferralCount:
          (json['qualified_referral_count'] as num?)?.toInt() ?? 0,
      claimableCount: (json['claimable_count'] as num?)?.toInt() ?? 0,
      rewards: rewardJson is List
          ? rewardJson
                .whereType<Map<String, dynamic>>()
                .map(ReferralReward.fromJson)
                .toList(growable: false)
          : const [],
      hasAttribution: json['attribution'] is Map,
    );
  }
}

class ReferralClaimPreparation {
  const ReferralClaimPreparation({
    required this.rewardId,
    required this.platform,
    required this.offerId,
    required this.productId,
    required this.claimToken,
  });

  final int rewardId;
  final String platform;
  final String offerId;
  final String productId;
  final String claimToken;

  factory ReferralClaimPreparation.fromJson(Map<String, dynamic> json) {
    return ReferralClaimPreparation(
      rewardId: (json['reward_id'] as num).toInt(),
      platform: json['platform'] as String,
      offerId: json['offer_id'] as String,
      productId: json['product_id'] as String,
      claimToken: json['claim_token'] as String,
    );
  }
}

class ReferralApi {
  ReferralApi._();

  static Future<Map<String, String>> _headers() async => {
    ...await AccountStorage.getAuthHeaders(),
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ReferralApiException(
        detail ?? 'Referral request failed.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ReferralApiException('Invalid referral response.');
    }
    return decoded;
  }

  static Future<ReferralIdentity> myReferralIdentity() async {
    try {
      final summary = await mySummary();
      return summary.identity;
    } on ReferralApiException catch (error) {
      // Migration-safe fallback while the financial referral tables roll out.
      if (error.statusCode != 503) rethrow;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/community/referrals/me'),
        headers: await _headers(),
      );
      final decoded = _decode(response);
      return ReferralIdentity(
        code: decoded['referral_code'] as String,
        shareUrl: decoded['share_url'] as String,
      );
    }
  }

  static Future<ReferralSummary> mySummary() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/referrals/me'),
      headers: await _headers(),
    );
    return ReferralSummary.fromJson(_decode(response));
  }

  static Future<void> redeem(String code, {String source = 'manual'}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/referrals/redeem'),
      headers: await _headers(),
      body: jsonEncode({'code': code.trim().toUpperCase(), 'source': source}),
    );
    _decode(response);
  }

  static Future<ReferralClaimPreparation> prepareClaim({
    required int rewardId,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/referrals/rewards/$rewardId/claim'),
      headers: await _headers(),
      body: jsonEncode({'platform': platform}),
    );
    return ReferralClaimPreparation.fromJson(_decode(response));
  }
}
