class ApplePromotionalOfferAuthorization {
  const ApplePromotionalOfferAuthorization({
    required this.offerId,
    required this.keyId,
    required this.nonce,
    required this.timestamp,
    required this.signature,
  });

  final String offerId;
  final String keyId;
  final String nonce;
  final int timestamp;
  final String signature;

  factory ApplePromotionalOfferAuthorization.fromJson({
    required String offerId,
    required Map<String, dynamic> json,
  }) {
    return ApplePromotionalOfferAuthorization(
      offerId: offerId,
      keyId: json['key_id'] as String,
      nonce: json['nonce'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      signature: json['signature'] as String,
    );
  }
}

class CoachApprovalOfferStatus {
  const CoachApprovalOfferStatus({
    required this.eligible,
    required this.used,
    required this.reason,
    this.pendingClaimToken,
  });

  final bool eligible;
  final bool used;
  final String reason;
  final String? pendingClaimToken;

  factory CoachApprovalOfferStatus.fromJson(Map<String, dynamic> json) {
    final pending = json['pending_claim_token']?.toString().trim();
    return CoachApprovalOfferStatus(
      eligible: json['eligible'] == true,
      used: json['used'] == true,
      reason: json['reason']?.toString() ?? '',
      pendingClaimToken: pending == null || pending.isEmpty ? null : pending,
    );
  }
}

class CoachApprovalOfferPreparation {
  const CoachApprovalOfferPreparation({
    required this.productId,
    required this.claimToken,
    required this.authorization,
  });

  final String productId;
  final String claimToken;
  final ApplePromotionalOfferAuthorization authorization;

  factory CoachApprovalOfferPreparation.fromJson(Map<String, dynamic> json) {
    final productId = json['product_id'] as String;
    final offerId = json['offer_id'] as String;
    return CoachApprovalOfferPreparation(
      productId: productId,
      claimToken: json['claim_token'] as String,
      authorization: ApplePromotionalOfferAuthorization.fromJson(
        offerId: offerId,
        json: Map<String, dynamic>.from(json['apple_offer_signature'] as Map),
      ),
    );
  }
}
