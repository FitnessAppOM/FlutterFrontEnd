import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

typedef StoreAvailabilityCheck = Future<bool> Function();
typedef StoreProductQuery =
    Future<ProductDetailsResponse> Function(Set<String> productIds);
typedef StoreProductLoadLogger = void Function(String message);
typedef StoreProductLoadDelay = Future<void> Function(Duration duration);

class StoreProductLoadResult {
  const StoreProductLoadResult({
    required this.storeAvailable,
    required this.attempts,
    this.response,
    this.error,
    this.stackTrace,
  });

  final bool storeAvailable;
  final int attempts;
  final ProductDetailsResponse? response;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasProducts => response?.productDetails.isNotEmpty == true;
}

class StoreProductLoader {
  StoreProductLoader({
    required StoreAvailabilityCheck isAvailable,
    required StoreProductQuery queryProducts,
    required StoreProductLoadLogger logger,
    this.maxAttempts = 3,
    this.attemptTimeout = const Duration(seconds: 12),
    this.initialRetryDelay = const Duration(milliseconds: 750),
    StoreProductLoadDelay? delay,
  }) : assert(maxAttempts > 0),
       _isAvailable = isAvailable,
       _queryProducts = queryProducts,
       _logger = logger,
       _delay = delay ?? Future<void>.delayed;

  final StoreAvailabilityCheck _isAvailable;
  final StoreProductQuery _queryProducts;
  final StoreProductLoadLogger _logger;
  final StoreProductLoadDelay _delay;
  final int maxAttempts;
  final Duration attemptTimeout;
  final Duration initialRetryDelay;

  Future<StoreProductLoadResult> load(Set<String> productIds) async {
    ProductDetailsResponse? lastResponse;
    Object? lastError;
    StackTrace? lastStackTrace;
    var storeAvailable = false;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        storeAvailable = await _isAvailable().timeout(attemptTimeout);
        _logger(
          'attempt=$attempt/$maxAttempts availability=$storeAvailable '
          'requested=${productIds.toList()..sort()}',
        );
        if (!storeAvailable) {
          lastError = StateError(
            'StoreKit reported that payments are unavailable.',
          );
          lastStackTrace = StackTrace.current;
        } else {
          final response = await _queryProducts(
            productIds,
          ).timeout(attemptTimeout);
          lastResponse = response;
          final foundIds =
              response.productDetails.map((product) => product.id).toList()
                ..sort();
          final notFoundIds = response.notFoundIDs.toList()..sort();
          _logger(
            'attempt=$attempt/$maxAttempts requested=${productIds.toList()..sort()} '
            'found=$foundIds notFound=$notFoundIds '
            'errorCode=${response.error?.code} '
            'errorMessage=${response.error?.message} '
            'errorDetails=${response.error?.details}',
          );
          if (response.productDetails.isNotEmpty) {
            return StoreProductLoadResult(
              storeAvailable: true,
              attempts: attempt,
              response: response,
            );
          }
          lastError = response.error;
          lastStackTrace = StackTrace.current;
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        _logger(
          'attempt=$attempt/$maxAttempts threw=${error.runtimeType} error=$error',
        );
      }

      if (attempt < maxAttempts) {
        final multiplier = 1 << (attempt - 1);
        await _delay(initialRetryDelay * multiplier);
      }
    }

    _logger(
      'exhausted attempts=$maxAttempts availability=$storeAvailable '
      'lastError=$lastError notFound=${lastResponse?.notFoundIDs}',
    );
    return StoreProductLoadResult(
      storeAvailable: storeAvailable,
      attempts: maxAttempts,
      response: lastResponse,
      error: lastError,
      stackTrace: lastStackTrace,
    );
  }
}
