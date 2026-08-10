import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/purchases/apple_storekit_entitlement_recovery.dart';

void main() {
  group('AppleStoreKitEntitlementTransaction', () {
    test('parses a complete native transaction payload', () {
      final transaction = AppleStoreKitEntitlementTransaction.fromMap({
        'transactionId': '2000001',
        'originalTransactionId': '2000000',
        'productId': 'taqa_coach_monthly',
        'signedTransaction': 'header.payload.signature',
        'purchaseDateMs': 1700000000000,
        'expirationDateMs': 1700003600000,
        'appAccountToken': 'account-token',
      });

      expect(transaction, isNotNull);
      expect(transaction!.productId, 'taqa_coach_monthly');
      expect(transaction.signedTransaction, 'header.payload.signature');
      expect(transaction.appAccountToken, 'account-token');
      expect(transaction.purchaseDate.isUtc, isTrue);
      expect(transaction.expirationDate.isUtc, isTrue);
    });

    test('rejects a payload without signed verification data', () {
      final transaction = AppleStoreKitEntitlementTransaction.fromMap({
        'transactionId': '2000001',
        'originalTransactionId': '2000000',
        'productId': 'taqa_coach_monthly',
        'signedTransaction': '',
        'purchaseDateMs': 1700000000000,
        'expirationDateMs': 1700003600000,
      });

      expect(transaction, isNull);
    });
  });

  group('AppleStoreKitEntitlementRecovery.prioritize', () {
    final now = DateTime.utc(2026, 8, 10, 12);

    AppleStoreKitEntitlementTransaction transaction({
      required String id,
      required String productId,
      required DateTime expiration,
    }) {
      return AppleStoreKitEntitlementTransaction(
        transactionId: id,
        originalTransactionId: 'original-$id',
        productId: productId,
        signedTransaction: 'signed-$id',
        purchaseDate: now.subtract(const Duration(minutes: 1)),
        expirationDate: expiration,
      );
    }

    test('drops expired transactions', () {
      final result = AppleStoreKitEntitlementRecovery.prioritize([
        transaction(
          id: 'expired',
          productId: 'standard',
          expiration: now.subtract(const Duration(seconds: 1)),
        ),
        transaction(
          id: 'active',
          productId: 'standard',
          expiration: now.add(const Duration(minutes: 5)),
        ),
      ], activeAt: now);

      expect(result.map((item) => item.transactionId), ['active']);
    });

    test('puts the requested product before a later-expiring other plan', () {
      final result = AppleStoreKitEntitlementRecovery.prioritize(
        [
          transaction(
            id: 'coach',
            productId: 'coach',
            expiration: now.add(const Duration(minutes: 5)),
          ),
          transaction(
            id: 'standard',
            productId: 'standard',
            expiration: now.add(const Duration(hours: 1)),
          ),
        ],
        activeAt: now,
        preferredProductId: 'coach',
      );

      expect(result.first.productId, 'coach');
    });
  });
}
