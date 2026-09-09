import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:taqaproject/services/purchases/store_product_loader.dart';

void main() {
  const productIds = <String>{'monthly', 'annual'};

  ProductDetails product(String id) => ProductDetails(
    id: id,
    title: id,
    description: id,
    price: r'$5.99',
    rawPrice: 5.99,
    currencyCode: 'USD',
  );

  test('retries unavailable StoreKit before querying products', () async {
    var availabilityChecks = 0;
    var queries = 0;
    final delays = <Duration>[];
    final logs = <String>[];
    final loader = StoreProductLoader(
      isAvailable: () async => ++availabilityChecks >= 2,
      queryProducts: (ids) async {
        queries++;
        return ProductDetailsResponse(
          productDetails: <ProductDetails>[product('monthly')],
          notFoundIDs: const <String>[],
        );
      },
      logger: logs.add,
      delay: (duration) async => delays.add(duration),
    );

    final result = await loader.load(productIds);

    expect(result.hasProducts, isTrue);
    expect(result.attempts, 2);
    expect(availabilityChecks, 2);
    expect(queries, 1);
    expect(delays, <Duration>[const Duration(milliseconds: 750)]);
    expect(logs, contains(contains('availability=false')));
  });

  test('retries an empty product response and records not-found IDs', () async {
    var queries = 0;
    final logs = <String>[];
    final loader = StoreProductLoader(
      isAvailable: () async => true,
      queryProducts: (ids) async {
        queries++;
        if (queries == 1) {
          return ProductDetailsResponse(
            productDetails: const <ProductDetails>[],
            notFoundIDs: ids.toList(),
          );
        }
        return ProductDetailsResponse(
          productDetails: <ProductDetails>[
            product('monthly'),
            product('annual'),
          ],
          notFoundIDs: const <String>[],
        );
      },
      logger: logs.add,
      delay: (_) async {},
    );

    final result = await loader.load(productIds);

    expect(result.hasProducts, isTrue);
    expect(result.attempts, 2);
    expect(queries, 2);
    expect(logs.join('\n'), contains('notFound=[annual, monthly]'));
  });

  test(
    'preserves the final StoreKit error after retries are exhausted',
    () async {
      final errors = <IAPError>[];
      final loader = StoreProductLoader(
        isAvailable: () async => true,
        queryProducts: (ids) async {
          final error = IAPError(
            source: 'app_store',
            code: 'storekit_no_response',
            message: 'StoreKit failed to respond.',
            details: <String, Object>{'attempt': errors.length + 1},
          );
          errors.add(error);
          return ProductDetailsResponse(
            productDetails: const <ProductDetails>[],
            notFoundIDs: ids.toList(),
            error: error,
          );
        },
        logger: (_) {},
        delay: (_) async {},
      );

      final result = await loader.load(productIds);

      expect(result.hasProducts, isFalse);
      expect(result.attempts, 3);
      expect(result.error, same(errors.last));
      expect(result.response?.notFoundIDs, containsAll(productIds));
    },
  );

  test('times out a stalled StoreKit call and retries', () async {
    var availabilityChecks = 0;
    final loader = StoreProductLoader(
      isAvailable: () {
        availabilityChecks++;
        return Future<bool>.delayed(
          const Duration(milliseconds: 20),
          () => true,
        );
      },
      queryProducts: (_) async => ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
      logger: (_) {},
      maxAttempts: 2,
      attemptTimeout: const Duration(milliseconds: 1),
      delay: (_) async {},
    );

    final result = await loader.load(productIds);

    expect(result.hasProducts, isFalse);
    expect(result.error, isA<TimeoutException>());
    expect(availabilityChecks, 2);
  });
}
