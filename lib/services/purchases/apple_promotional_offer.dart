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
