import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class AppleStoreKitEntitlementTransaction {
  const AppleStoreKitEntitlementTransaction({
    required this.transactionId,
    required this.originalTransactionId,
    required this.productId,
    required this.signedTransaction,
    required this.purchaseDate,
    required this.expirationDate,
    this.appAccountToken,
  });

  final String transactionId;
  final String originalTransactionId;
  final String productId;
  final String signedTransaction;
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final String? appAccountToken;

  bool isActiveAt(DateTime instant) => expirationDate.isAfter(instant.toUtc());

  static AppleStoreKitEntitlementTransaction? fromMap(
    Map<Object?, Object?> value,
  ) {
    final transactionId = value['transactionId']?.toString().trim() ?? '';
    final originalTransactionId =
        value['originalTransactionId']?.toString().trim() ?? '';
    final productId = value['productId']?.toString().trim() ?? '';
    final signedTransaction =
        value['signedTransaction']?.toString().trim() ?? '';
    final purchaseDateMs = _milliseconds(value['purchaseDateMs']);
    final expirationDateMs = _milliseconds(value['expirationDateMs']);
    if (transactionId.isEmpty ||
        originalTransactionId.isEmpty ||
        productId.isEmpty ||
        signedTransaction.isEmpty ||
        purchaseDateMs == null ||
        expirationDateMs == null) {
      return null;
    }
    return AppleStoreKitEntitlementTransaction(
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      productId: productId,
      signedTransaction: signedTransaction,
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(
        purchaseDateMs,
        isUtc: true,
      ),
      expirationDate: DateTime.fromMillisecondsSinceEpoch(
        expirationDateMs,
        isUtc: true,
      ),
      appAccountToken: _nonEmpty(value['appAccountToken']),
    );
  }

  static int? _milliseconds(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Reads verified StoreKit 2 subscription transactions directly.
///
/// The in_app_purchase restore stream is still the primary path. This channel
/// covers the StoreKit edge case where the purchase sheet reports that the
/// Apple ID is already subscribed but restore emits no PurchaseDetails event.
class AppleStoreKitEntitlementRecovery {
  AppleStoreKitEntitlementRecovery._();

  static const MethodChannel _channel = MethodChannel(
    'taqa/apple_subscription_entitlements',
  );
  static const Duration _timeout = Duration(seconds: 5);

  static Future<List<AppleStoreKitEntitlementTransaction>> activeTransactions({
    required Set<String> productIds,
    DateTime? now,
  }) async {
    if (!Platform.isIOS || productIds.isEmpty) {
      return const <AppleStoreKitEntitlementTransaction>[];
    }
    final values = await _channel
        .invokeListMethod<Object?>('activeTransactions', {
          'productIds': productIds.toList(growable: false),
        })
        .timeout(_timeout);
    final parsed = <AppleStoreKitEntitlementTransaction>[];
    for (final value in values ?? const <Object?>[]) {
      if (value is! Map) continue;
      final transaction = AppleStoreKitEntitlementTransaction.fromMap(value);
      if (transaction != null) parsed.add(transaction);
    }
    return prioritize(parsed, activeAt: now ?? DateTime.now().toUtc());
  }

  static List<AppleStoreKitEntitlementTransaction> prioritize(
    Iterable<AppleStoreKitEntitlementTransaction> transactions, {
    required DateTime activeAt,
    String? preferredProductId,
  }) {
    final active = transactions
        .where((transaction) => transaction.isActiveAt(activeAt))
        .toList(growable: false);
    active.sort((left, right) {
      final leftPreferred = left.productId == preferredProductId ? 1 : 0;
      final rightPreferred = right.productId == preferredProductId ? 1 : 0;
      final preferredOrder = rightPreferred.compareTo(leftPreferred);
      if (preferredOrder != 0) return preferredOrder;
      final expirationOrder = right.expirationDate.compareTo(
        left.expirationDate,
      );
      if (expirationOrder != 0) return expirationOrder;
      return right.purchaseDate.compareTo(left.purchaseDate);
    });
    return active;
  }
}
