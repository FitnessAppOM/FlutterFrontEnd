import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class BillingApiException implements Exception {
  const BillingApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GoogleBillingOffering {
  const GoogleBillingOffering({
    required this.productId,
    required this.basePlanId,
    required this.offerTag,
    required this.planCode,
  });

  final String productId;
  final String? basePlanId;
  final String? offerTag;
  final String planCode;

  factory GoogleBillingOffering.fromJson(Map<String, dynamic> json) {
    return GoogleBillingOffering(
      productId: json['product_id'] as String,
      basePlanId: json['base_plan_id'] as String?,
      offerTag: json['offer_tag'] as String?,
      planCode: json['plan_code'] as String,
    );
  }
}

class GoogleBillingOfferings {
  const GoogleBillingOfferings({
    required this.obfuscatedAccountId,
    required this.products,
  });

  final String obfuscatedAccountId;
  final List<GoogleBillingOffering> products;
}

class BillingVerificationResult {
  const BillingVerificationResult({
    required this.active,
    required this.entitlementCodes,
  });

  final bool active;
  final Set<String> entitlementCodes;
  bool get coachActive => entitlementCodes.contains('coach_tools');
}

class BillingApi {
  BillingApi._();

  static Future<Map<String, String>> _headers() async => {
    ...await AccountStorage.getAuthHeaders(),
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const BillingApiException(
        'The billing server returned an invalid response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BillingApiException(
        decoded['detail'] as String? ??
            'The subscription could not be verified.',
      );
    }
    return decoded;
  }

  static Future<GoogleBillingOfferings> googleOfferings() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/billing/offerings?platform=android'),
      headers: await _headers(),
    );
    final json = _decode(response);
    final rawProducts = json['products'] as List<dynamic>? ?? const [];
    return GoogleBillingOfferings(
      obfuscatedAccountId: json['google_obfuscated_account_id'] as String,
      products: rawProducts
          .map(
            (item) =>
                GoogleBillingOffering.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  static Future<BillingVerificationResult> verifyGooglePurchase({
    required String productId,
    required String purchaseToken,
    String? purchaseId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/billing/purchases/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'platform': 'android',
        'product_id': productId,
        'purchase_token': purchaseToken,
        if (purchaseId != null) 'purchase_id': purchaseId,
      }),
    );
    final json = _decode(response);
    return BillingVerificationResult(
      active: json['active'] == true,
      entitlementCodes: Set<String>.from(
        json['entitlement_codes'] as List<dynamic>? ?? const [],
      ),
    );
  }

  static Future<BillingVerificationResult> entitlements() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/billing/entitlements/me'),
      headers: await _headers(),
    );
    final json = _decode(response);
    return BillingVerificationResult(
      active: json['active'] == true,
      entitlementCodes: Set<String>.from(
        json['entitlement_codes'] as List<dynamic>? ?? const [],
      ),
    );
  }
}
