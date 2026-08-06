import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

class AppleBillingException implements Exception {
  const AppleBillingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppleBillingEntitlement {
  const AppleBillingEntitlement({
    required this.active,
    this.expiresAt,
    this.productId,
    this.planCode,
    this.platform,
    this.autoRenew,
    this.subscriptions = const <StoreBillingSubscription>[],
    this.pendingChange,
  });

  final bool active;
  final DateTime? expiresAt;
  final String? productId;
  final String? planCode;
  final String? platform;
  final bool? autoRenew;
  final List<StoreBillingSubscription> subscriptions;
  final PendingSubscriptionChange? pendingChange;

  bool hasActiveSubscriptionFromAnotherStore(String currentPlatform) {
    if (subscriptions.isNotEmpty) {
      return subscriptions.any(
        (subscription) => subscription.platform != currentPlatform,
      );
    }
    return active && platform != null && platform != currentPlatform;
  }
}

class StoreBillingSubscription {
  const StoreBillingSubscription({
    required this.platform,
    required this.productId,
    this.planCode,
    this.expiresAt,
    this.autoRenew,
  });

  final String platform;
  final String productId;
  final String? planCode;
  final DateTime? expiresAt;
  final bool? autoRenew;
}

class PendingSubscriptionChange {
  const PendingSubscriptionChange({
    required this.platform,
    required this.currentProductId,
    required this.targetProductId,
    required this.effectiveAt,
  });

  final String platform;
  final String currentProductId;
  final String targetProductId;
  final DateTime effectiveAt;
}

class GoogleBillingOfferings {
  const GoogleBillingOfferings({
    required this.productIds,
    required this.productIdsByPlanCode,
    required this.obfuscatedAccountId,
  });

  final Set<String> productIds;
  final Map<String, String> productIdsByPlanCode;
  final String obfuscatedAccountId;
}

/// Connects App Store and Google Play purchases to Taqa's entitlement server.
class AppleBillingService {
  AppleBillingService._();

  static const _timeout = Duration(seconds: 12);

  static Future<String> fetchAccountToken() async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/billing/apple/account-token'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(body));
    }
    final token = body['app_account_token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw const AppleBillingException(
        'Your Apple subscription could not be linked right now.',
      );
    }
    return token;
  }

  static Future<AppleBillingEntitlement> verifyPurchase({
    required String productId,
    required String signedTransaction,
    required String entitlementCode,
  }) async {
    if (signedTransaction.trim().isEmpty) {
      throw const AppleBillingException(
        'Apple did not return purchase verification data. Please restore your purchases.',
      );
    }
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/billing/apple/purchases/verify'),
          headers: await _headers(jsonBody: true),
          body: jsonEncode({
            'platform': 'ios',
            'product_id': productId,
            'signed_transaction': signedTransaction,
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(body));
    }

    final subscription = body['subscription'];
    final subscriptionMap = subscription is Map
        ? Map<String, dynamic>.from(subscription)
        : <String, dynamic>{};
    final codes = _stringSet(body['entitlement_codes']);
    return AppleBillingEntitlement(
      active:
          subscriptionMap['entitled'] == true &&
          codes.contains(entitlementCode),
      expiresAt: _date(subscriptionMap['current_period_end']),
      productId: _nonEmptyString(subscriptionMap['product_id']),
      planCode: _nonEmptyString(subscriptionMap['plan_code']),
      platform: _nonEmptyString(subscriptionMap['platform']),
      autoRenew: _bool(subscriptionMap['auto_renew']),
    );
  }

  static Future<AppleBillingEntitlement> verifyGooglePurchase({
    required String productId,
    required String purchaseToken,
    required String entitlementCode,
  }) async {
    if (purchaseToken.trim().isEmpty) {
      throw const AppleBillingException(
        'Google Play did not return purchase verification data.',
      );
    }
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/billing/purchases/verify'),
          headers: await _headers(jsonBody: true),
          body: jsonEncode({
            'platform': 'android',
            'product_id': productId,
            'purchase_token': purchaseToken,
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(body));
    }
    return _entitlementFromVerification(body, entitlementCode);
  }

  static Future<GoogleBillingOfferings> fetchGoogleOfferings() async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/billing/offerings?platform=android'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(body));
    }
    final accountId =
        _nonEmptyString(body['google_obfuscated_account_id']) ?? '';
    if (accountId.isEmpty) {
      throw const AppleBillingException(
        'Google Play could not be linked to this Taqa account.',
      );
    }
    final productIds = <String>{};
    final productIdsByPlanCode = <String, String>{};
    final products = body['products'];
    if (products is List) {
      for (final raw in products) {
        if (raw is! Map) continue;
        final productId = _nonEmptyString(raw['product_id']);
        final planCode = _nonEmptyString(raw['plan_code']);
        if (productId != null) {
          productIds.add(productId);
          if (planCode != null) productIdsByPlanCode[planCode] = productId;
        }
      }
    }
    return GoogleBillingOfferings(
      productIds: productIds,
      productIdsByPlanCode: productIdsByPlanCode,
      obfuscatedAccountId: accountId,
    );
  }

  static Future<void> savePendingSubscriptionChange({
    required String platform,
    required String targetProductId,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.baseUrl}/billing/subscription-changes/pending',
          ),
          headers: await _headers(jsonBody: true),
          body: jsonEncode({
            'platform': platform,
            'target_product_id': targetProductId,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(_decode(response)));
    }
  }

  static Future<AppleBillingEntitlement> fetchEntitlement(
    String entitlementCode,
  ) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/billing/entitlements/me'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppleBillingException(_errorMessage(body));
    }

    DateTime? latestExpiration;
    final rawEntitlements = body['entitlements'];
    if (rawEntitlements is List) {
      for (final raw in rawEntitlements) {
        if (raw is! Map) continue;
        final entitlement = Map<String, dynamic>.from(raw);
        if (entitlement['code']?.toString() != entitlementCode ||
            entitlement['status']?.toString() != 'active') {
          continue;
        }
        final expiration = _date(entitlement['valid_until']);
        if (expiration != null &&
            (latestExpiration == null ||
                expiration.isAfter(latestExpiration))) {
          latestExpiration = expiration;
        }
      }
    }
    final subscription = body['subscription'];
    final subscriptionMap = subscription is Map
        ? Map<String, dynamic>.from(subscription)
        : <String, dynamic>{};
    final subscriptions = _subscriptions(body['subscriptions']);
    final pendingChange = _pendingChange(body['pending_subscription_change']);
    return AppleBillingEntitlement(
      active: _stringSet(body['entitlement_codes']).contains(entitlementCode),
      expiresAt:
          _date(subscriptionMap['current_period_end']) ?? latestExpiration,
      productId: _nonEmptyString(subscriptionMap['product_id']),
      planCode: _nonEmptyString(subscriptionMap['plan_code']),
      platform: _nonEmptyString(subscriptionMap['platform']),
      autoRenew: _bool(subscriptionMap['auto_renew']),
      subscriptions: subscriptions,
      pendingChange: pendingChange,
    );
  }

  static AppleBillingEntitlement _entitlementFromVerification(
    Map<String, dynamic> body,
    String entitlementCode,
  ) {
    final subscription = body['subscription'];
    final subscriptionMap = subscription is Map
        ? Map<String, dynamic>.from(subscription)
        : <String, dynamic>{};
    final codes = _stringSet(body['entitlement_codes']);
    return AppleBillingEntitlement(
      active:
          subscriptionMap['entitled'] == true &&
          codes.contains(entitlementCode),
      expiresAt: _date(subscriptionMap['current_period_end']),
      productId: _nonEmptyString(subscriptionMap['product_id']),
      planCode: _nonEmptyString(subscriptionMap['plan_code']),
      platform: _nonEmptyString(subscriptionMap['platform']),
      autoRenew: _bool(subscriptionMap['auto_renew']),
    );
  }

  static List<StoreBillingSubscription> _subscriptions(dynamic value) {
    if (value is! List) return const <StoreBillingSubscription>[];
    final subscriptions = <StoreBillingSubscription>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final platform = _nonEmptyString(item['platform']);
      final productId = _nonEmptyString(item['product_id']);
      if (platform == null || productId == null) continue;
      subscriptions.add(
        StoreBillingSubscription(
          platform: platform,
          productId: productId,
          planCode: _nonEmptyString(item['plan_code']),
          expiresAt: _date(item['current_period_end']),
          autoRenew: _bool(item['auto_renew']),
        ),
      );
    }
    return subscriptions;
  }

  static PendingSubscriptionChange? _pendingChange(dynamic value) {
    if (value is! Map) return null;
    final item = Map<String, dynamic>.from(value);
    final platform = _nonEmptyString(item['platform']);
    final currentProductId = _nonEmptyString(item['current_product_id']);
    final targetProductId = _nonEmptyString(item['target_product_id']);
    final effectiveAt = _date(item['effective_at']);
    if (platform == null ||
        currentProductId == null ||
        targetProductId == null ||
        effectiveAt == null) {
      return null;
    }
    return PendingSubscriptionChange(
      platform: platform,
      currentProductId: currentProductId,
      targetProductId: targetProductId,
      effectiveAt: effectiveAt,
    );
  }

  static Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final headers = await AccountStorage.getAuthHeaders();
    if (!headers.containsKey('Authorization')) {
      throw const AppleBillingException(
        'Please sign in again before linking your subscription.',
      );
    }
    if (jsonBody) headers['Content-Type'] = 'application/json';
    return headers;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _errorMessage(Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    return 'Your subscription could not be verified. Please try again.';
  }

  static Set<String> _stringSet(dynamic value) {
    if (value is! List) return <String>{};
    return value.map((item) => item.toString()).toSet();
  }

  static String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value == 1 || value?.toString().toLowerCase() == 'true') return true;
    if (value == 0 || value?.toString().toLowerCase() == 'false') return false;
    return null;
  }

  static DateTime? _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toUtc();
  }
}
