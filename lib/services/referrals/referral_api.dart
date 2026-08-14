import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import '../purchases/apple_promotional_offer.dart';

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
    this.claimable = false,
  });

  final int id;
  final String type;
  final String status;
  final String? billingPeriod;
  final String? platform;
  final bool claimable;

  bool get isClaimable => claimable;

  factory ReferralReward.fromJson(Map<String, dynamic> json) {
    return ReferralReward(
      id: (json['id'] as num).toInt(),
      type: json['reward_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      billingPeriod: json['billing_period'] as String?,
      platform: json['platform'] as String?,
      claimable: json['claimable'] == true,
    );
  }
}

class CoachReferralProgress {
  const CoachReferralProgress({
    required this.qualifiedCount,
    required this.discountThreshold,
    required this.freeThreshold,
  });

  final int qualifiedCount;
  final int discountThreshold;
  final int freeThreshold;

  factory CoachReferralProgress.fromJson(Map<String, dynamic>? json) {
    return CoachReferralProgress(
      qualifiedCount: (json?['qualified_count'] as num?)?.toInt() ?? 0,
      discountThreshold: (json?['discount_threshold'] as num?)?.toInt() ?? 10,
      freeThreshold: (json?['free_threshold'] as num?)?.toInt() ?? 20,
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
    required this.monthlyCoachProgress,
    required this.yearlyCoachProgress,
  });

  final ReferralIdentity identity;
  final int qualifiedReferralCount;
  final int claimableCount;
  final List<ReferralReward> rewards;
  final bool hasAttribution;
  final CoachReferralProgress monthlyCoachProgress;
  final CoachReferralProgress yearlyCoachProgress;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final rewardJson = json['rewards'];
    final progressJson = json['coach_progress'];
    final progress = progressJson is Map<String, dynamic>
        ? progressJson
        : const <String, dynamic>{};
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
      monthlyCoachProgress: CoachReferralProgress.fromJson(
        progress['monthly'] is Map<String, dynamic>
            ? progress['monthly'] as Map<String, dynamic>
            : null,
      ),
      yearlyCoachProgress: CoachReferralProgress.fromJson(
        progress['yearly'] is Map<String, dynamic>
            ? progress['yearly'] as Map<String, dynamic>
            : null,
      ),
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
    this.appleOfferAuthorization,
  });

  final int rewardId;
  final String platform;
  final String offerId;
  final String productId;
  final String claimToken;
  final ApplePromotionalOfferAuthorization? appleOfferAuthorization;

  factory ReferralClaimPreparation.fromJson(Map<String, dynamic> json) {
    final offerId = json['offer_id'] as String;
    final appleSignature = json['apple_offer_signature'];
    return ReferralClaimPreparation(
      rewardId: (json['reward_id'] as num).toInt(),
      platform: json['platform'] as String,
      offerId: offerId,
      productId: json['product_id'] as String,
      claimToken: json['claim_token'] as String,
      appleOfferAuthorization: appleSignature is Map<String, dynamic>
          ? ApplePromotionalOfferAuthorization.fromJson(
              offerId: offerId,
              json: appleSignature,
            )
          : null,
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

  static Future<void> skipOnboarding() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/referrals/onboarding/decision'),
      headers: await _headers(),
      body: jsonEncode({'decision': 'skip'}),
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
