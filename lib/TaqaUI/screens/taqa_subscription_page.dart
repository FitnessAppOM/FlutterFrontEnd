import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/email_verification_page.dart';
import '../../core/account_storage.dart';
import '../../core/user_friendly_error.dart';
import '../../localization/app_localizations.dart';
import '../../screens/welcome.dart';
import '../../services/core/notification_service.dart';
import '../../services/core/remote_push_service.dart';
import '../../services/auth/profile_service.dart';
import '../../services/purchases/apple_billing_service.dart';
import '../../services/purchases/apple_promotional_offer.dart';
import '../../services/purchases/apple_storekit_entitlement_recovery.dart';
import '../../services/purchases/billing_api.dart';
import '../../services/purchases/taqa_subscription_catalog.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_filled_button.dart';
import '../components/taqa_page_app_bar.dart';
import '../components/taqa_popup_guard.dart';
import '../components/taqa_refresh_indicator.dart';
import '../components/taqa_subscription_plan_card.dart';
import '../components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../components/taqa_toast.dart';
import '../components/taqa_value_dialog.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

enum _SubscriptionAccountAction { freeze, delete, logout }

enum _RecoveryOutcome { activated, notFound, failed }

/// Taqa Fitness subscriptions purchased through the App Store / StoreKit.
class TaqaSubscriptionPage extends StatefulWidget {
  const TaqaSubscriptionPage({
    super.key,
    this.mandatory = false,
    this.plans,
    this.coachMembership = false,
    this.allowPlanTypeSwitch = true,
    this.allowBackNavigation = false,
    this.referralClaimToken,
    this.googleReferralOfferTag,
    this.referralProductId,
    this.appleOfferAuthorization,
  });

  /// When opened after onboarding, the user must subscribe or restore a
  /// subscription before the app can continue to their generated plan.
  final bool mandatory;

  /// Limits checkout to a particular subscription offering, such as the
  /// coach membership.
  final List<TaqaSubscriptionPlan>? plans;

  /// Marks a completed StoreKit transaction as an active coach membership.
  final bool coachMembership;

  /// Lets approved coaches choose between the normal and coach offerings.
  /// A coach-tab checkout can disable this to keep that action focused on the
  /// coach membership it is unlocking.
  final bool allowPlanTypeSwitch;

  /// Lets an in-app, feature-specific checkout return to the feature lock
  /// screen. The app-wide mandatory subscription flow remains non-dismissible.
  final bool allowBackNavigation;

  final String? referralClaimToken;
  final String? googleReferralOfferTag;
  final String? referralProductId;
  final ApplePromotionalOfferAuthorization? appleOfferAuthorization;

  @override
  State<TaqaSubscriptionPage> createState() => _TaqaSubscriptionPageState();
}

class _TaqaSubscriptionPageState extends State<TaqaSubscriptionPage> {
  final InAppPurchase _store = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  final Map<String, ProductDetails> _products = {};
  bool _loading = true;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  bool _restoring = false;
  bool _accountActionInProgress = false;
  String? _checkoutProductId;
  bool _restoreRequested = false;
  bool _mandatoryRouteFinished = false;
  String? _selectedProductId;
  String? _pendingReplacementProductId;
  String? _pendingChangeAction;
  bool _lastActivationChangePending = false;
  String? _message;
  late bool _coachMembership;
  bool _coachPlanAvailable = false;
  Future<String?>? _activeProductLookup;
  DateTime? _activePlanEndsAt;
  AppleBillingEntitlement? _billingState;
  bool _billingPreflightFailed = false;
  String? _googleAccountId;
  Map<String, String> _googleProductIdsByPlanCode = const {};
  Map<String, GoogleBillingProductOffering> _googleOfferingsByProductId =
      const {};
  Set<String> _storeProductIds = const {};

  String _tr(String key, [Map<String, String> values = const {}]) {
    var text = AppLocalizations.of(context).translate(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _coachMembership = widget.coachMembership;
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: _handlePurchaseStreamError,
    );
    _loadProducts();
    unawaited(_loadCoachPlanEligibility());
    unawaited(_activeProductIdForCheckout());
  }

  Future<String?> _activeProductIdForCheckout() {
    return _activeProductLookup ??= _fetchActiveProductId();
  }

  Future<String?> _fetchActiveProductId() async {
    try {
      final entitlement = await AppleBillingService.fetchEntitlement(
        'app_full',
      );
      return _applyBillingState(entitlement);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCoachPlanEligibility() async {
    var approved =
        (await AccountStorage.getCoachApplicationStatus()) == 'approved';
    try {
      final userId = await AccountStorage.getUserId();
      if (userId != null && userId > 0) {
        final profile = await ProfileApi.fetchProfile(userId);
        final status = (profile['expert_profile_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        approved =
            profile['filled_expert_questionnaire'] == true &&
            status == 'approved' &&
            profile['is_expert'] == true;
        await AccountStorage.setCoachApplicationStatus(
          profile['filled_expert_questionnaire'] == true
              ? (status.isEmpty ? 'pending' : status)
              : null,
        );
      }
    } catch (_) {
      // The cached approval state is sufficient to keep the switch stable
      // while a short-lived profile request is unavailable.
    }
    if (!mounted) return;
    setState(() => _coachPlanAvailable = approved);
  }

  Future<void> _selectMembershipType(bool coachMembership) async {
    if (_coachMembership == coachMembership ||
        (coachMembership && !_coachPlanAvailable)) {
      return;
    }
    setState(() {
      _coachMembership = coachMembership;
      _selectedProductId = _firstAvailableProductId();
    });
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final available = await _store.isAvailable();
      if (!available) {
        _setStoreUnavailable();
        return;
      }

      var productIds = _knownProductIds;
      if (Platform.isAndroid) {
        final offerings = await AppleBillingService.fetchGoogleOfferings();
        _googleAccountId = offerings.obfuscatedAccountId;
        _googleProductIdsByPlanCode = offerings.productIdsByPlanCode;
        _googleOfferingsByProductId = offerings.productsById;
        productIds = offerings.productIds;
      }
      _storeProductIds = productIds;
      final response = await _store.queryProductDetails(productIds);
      if (!mounted) return;
      final reconcileGooglePurchase = Platform.isAndroid && widget.mandatory;
      String? storeMessage;
      setState(() {
        _storeAvailable = true;
        _products
          ..clear()
          ..addAll(_selectStoreProducts(response.productDetails));
        _selectedProductId =
            _catalogPlans
                .map(_storeProductIdForPlan)
                .contains(_selectedProductId)
            ? _selectedProductId
            : _firstAvailableProductId();
        _message = response.error?.message;
        if (_products.isEmpty && response.notFoundIDs.isNotEmpty) {
          _message = _tr('subscription_store_plans_unavailable', {
            'store': _storeName(),
          });
        }
        storeMessage = _message;
        _loading = reconcileGooglePurchase;
      });
      if (storeMessage != null) _showToast(storeMessage!);
      if (reconcileGooglePurchase) {
        await _reconcileOwnedGooglePurchase();
        if (!mounted || _mandatoryRouteFinished) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      _setStoreUnavailable();
    }
  }

  Future<bool> _reconcileOwnedGooglePurchase() async {
    if (!Platform.isAndroid || !widget.mandatory || _restoring) return false;
    if (mounted) {
      setState(() => _restoring = true);
    }
    try {
      final addition = _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) return false;

      for (final purchase in response.pastPurchases.reversed) {
        if (!_storeProductIds.contains(purchase.productID)) continue;
        final token = purchase.verificationData.serverVerificationData.trim();
        if (token.isEmpty) continue;
        try {
          final entitlement = await AppleBillingService.verifyGooglePurchase(
            productId: purchase.productID,
            purchaseToken: token,
            entitlementCode: 'app_full',
          );
          if (!entitlement.active) continue;
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          await _finishMandatorySubscription();
          return true;
        } on AppleBillingException {
          // A stale or differently-bound purchase must not prevent another
          // owned Google purchase from being checked.
        }
      }
      return false;
    } catch (_) {
      // A transient Play connection failure falls back to the normal paywall
      // and its manual Restore Purchases recovery action.
      return false;
    } finally {
      if (mounted && !_mandatoryRouteFinished) {
        setState(() => _restoring = false);
      }
    }
  }

  void _setStoreUnavailable() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _storeAvailable = false;
      _message = null;
    });
    _setMessage(_tr('subscription_store_unavailable', {'store': _storeName()}));
  }

  void _showToast(String message, {AppToastType type = AppToastType.error}) {
    if (!mounted) return;
    AppToast.show(
      context,
      message,
      type: type,
      position: AppToastPosition.bottom,
      rootOverlay: true,
    );
  }

  void _setMessage(String message, {AppToastType type = AppToastType.error}) {
    if (!mounted) return;
    setState(() => _message = message);
    _showToast(message, type: type);
  }

  void _handlePurchaseStreamError(Object _) {
    if (!mounted) return;
    _setStoreOperationIdle();
    _setMessage(
      _tr('subscription_store_process_failed', {'store': _storeName()}),
    );
  }

  void _setStoreOperationIdle({bool preserveExpectedProduct = false}) {
    if (!mounted) return;
    setState(() {
      _purchasePending = false;
      _restoring = false;
      _pendingReplacementProductId = null;
      _pendingChangeAction = null;
      if (!preserveExpectedProduct) _checkoutProductId = null;
      _restoreRequested = false;
    });
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_knownProductIds.contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        if (_isExpectedPurchaseUpdate(purchase) && mounted) {
          setState(() => _purchasePending = true);
        }
        continue;
      }

      // StoreKit can replay unfinished or historical transactions as soon as
      // this listener is attached. They must never bypass a mandatory gate.
      // They still need to be completed, otherwise StoreKit can block a new
      // purchase of that same product (for example Coach Yearly).
      if (!_isExpectedPurchaseUpdate(purchase)) {
        if (purchase.pendingCompletePurchase) {
          await _completePurchaseInBackground(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        final purchaseMessage = _purchaseErrorMessage(purchase);
        final recoverySignal =
            '$purchaseMessage ${purchase.error?.code ?? ''} '
            '${purchase.error?.details ?? ''}';
        if (!_purchaseMayAlreadyBeOwned(recoverySignal)) {
          _setStoreOperationIdle();
          _setMessage(purchaseMessage);
          return;
        }
        if (Platform.isIOS) {
          final outcome = await _recoverActiveAppleSubscription(
            preferredProductId: purchase.productID,
            scheduleIntro: true,
          );
          if (outcome != _RecoveryOutcome.notFound) return;
        } else {
          final outcome = await _recoverActiveGoogleSubscription(
            preferredProductId: purchase.productID,
            scheduleIntro: true,
          );
          if (outcome != _RecoveryOutcome.notFound) return;
        }
        await _restorePurchases(
          automatic: true,
          skipStorePreflight: true,
          emptyResultMessage: Platform.isIOS
              ? _tr('subscription_apple_owned_missing_transaction')
              : purchaseMessage,
        );
        return;
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          _setStoreOperationIdle();
          _setMessage(
            _tr('subscription_purchase_canceled'),
            type: AppToastType.info,
          );
        }
        return;
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final active = await _performSubscriptionActivation(purchase: purchase);
        if (!active) {
          if (purchase.pendingCompletePurchase) {
            await _completePurchaseInBackground(purchase);
          }
          if (_coachMembership) {
            await AccountStorage.setCoachMembershipActive(false);
          }
          if (!mounted) return;
          final existingMessage = _message;
          _setStoreOperationIdle();
          if (existingMessage == null) {
            _setMessage(
              _coachMembership
                  ? _tr('subscription_verify_coach_failed_restore')
                  : _tr('subscription_verify_failed_restore'),
            );
          }
          continue;
        }
        _setMessage(
          _lastActivationChangePending
              ? _tr('subscription_change_scheduled')
              : purchase.status == PurchaseStatus.restored
              ? _tr('subscription_restored_linked')
              : _pendingChangeAction == 'upgrade_to_coach'
              ? _tr('subscription_coach_active')
              : _tr('subscription_active_linked'),
          type: AppToastType.success,
        );
        if (widget.referralClaimToken != null && mounted) {
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        if (widget.mandatory && mounted) {
          await _finishMandatorySubscription(
            purchase: purchase,
            scheduleIntro:
                purchase.status == PurchaseStatus.purchased &&
                !_lastActivationChangePending,
          );
          return;
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (mounted) {
        _setStoreOperationIdle();
      }
    }
  }

  bool _isExpectedPurchaseUpdate(PurchaseDetails purchase) {
    if (!_isProductForCurrentMembership(purchase.productID)) return false;
    if (purchase.status == PurchaseStatus.restored) {
      return _restoreRequested || _checkoutProductId == purchase.productID;
    }
    if (_checkoutProductId != purchase.productID) return false;
    return purchase.status == PurchaseStatus.pending ||
        purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.purchased;
  }

  String _purchaseErrorMessage(PurchaseDetails purchase) {
    final details = purchase.error?.details;
    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }
    final message = purchase.error?.message.trim() ?? '';
    return message.isNotEmpty ? message : _tr('subscription_purchase_failed');
  }

  bool _purchaseMayAlreadyBeOwned(String message) {
    final normalized = message.toLowerCase().replaceAll('-', '_');
    return normalized.contains('currently subscribed') ||
        normalized.contains('already subscribed') ||
        normalized.contains('already owned') ||
        normalized.contains('already own') ||
        normalized.contains('item_already_owned') ||
        normalized.contains('duplicate_product');
  }

  Future<void> _completePurchaseInBackground(PurchaseDetails purchase) async {
    try {
      await _store.completePurchase(purchase);
    } catch (_) {
      // StoreKit will provide the unfinished transaction again on the next
      // launch, where it can be completed without blocking access.
    }
  }

  Future<bool> _performSubscriptionActivation({
    PurchaseDetails? purchase,
  }) async {
    _lastActivationChangePending = false;
    try {
      final entitlementCode = purchase == null
          ? _coachMembership
                ? 'coach_tools'
                : 'app_full'
          : _entitlementCodeForProduct(purchase.productID);
      final entitlement = purchase == null
          ? await AppleBillingService.fetchEntitlement(entitlementCode)
          : Platform.isAndroid
          ? await AppleBillingService.verifyGooglePurchase(
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
              entitlementCode: entitlementCode,
              replacementProductId: _pendingReplacementProductId,
              referralClaimToken: widget.referralClaimToken,
            )
          : await AppleBillingService.verifyPurchase(
              productId: purchase.productID,
              signedTransaction:
                  purchase.verificationData.serverVerificationData,
              entitlementCode: entitlementCode,
              reactivateAutoRenew: purchase.status == PurchaseStatus.purchased,
              referralClaimToken: widget.referralClaimToken,
            );
      return _acceptVerifiedEntitlement(
        entitlement,
        entitlementCode: entitlementCode,
        verifiedProductId: purchase?.productID ?? entitlement.productId ?? '',
      );
    } on AppleBillingException catch (error) {
      _setMessage(error.message);
      return false;
    } on TimeoutException {
      _setMessage(_tr('subscription_verification_timeout_restore'));
      return false;
    } catch (_) {
      _setMessage(_tr('subscription_verify_failed_restore'));
      return false;
    }
  }

  Future<bool> _acceptVerifiedEntitlement(
    AppleBillingEntitlement entitlement, {
    required String entitlementCode,
    required String verifiedProductId,
    bool enforceRequestedProduct = true,
  }) async {
    if (!entitlement.active) return false;
    final requestedProductId = enforceRequestedProduct
        ? _checkoutProductId
        : null;
    final requestedChangeIsPending =
        requestedProductId != null &&
        entitlement.pendingProductId == requestedProductId;
    if (requestedProductId != null &&
        requestedProductId != verifiedProductId &&
        !requestedChangeIsPending) {
      _setMessage(
        _tr('subscription_current_plan_still_active', {'store': _storeName()}),
        type: AppToastType.info,
      );
      return false;
    }
    _lastActivationChangePending = requestedChangeIsPending;
    _applyBillingState(entitlement);
    if (entitlementCode == 'coach_tools') {
      final expiration = entitlement.expiresAt;
      if (expiration == null || !expiration.isAfter(DateTime.now().toUtc())) {
        return false;
      }
      await AccountStorage.setCoachMembershipActive(
        true,
        expiresAt: expiration,
      );
    }
    return true;
  }

  String _entitlementCodeForProduct(String productId) {
    return _isCoachProductId(productId) ? 'coach_tools' : 'app_full';
  }

  bool _isCoachProductId(String productId) {
    if (TaqaSubscriptionCatalog.coachPlans.any(
      (plan) => plan.productId == productId,
    )) {
      return true;
    }
    return _googleOfferingsByProductId[productId]?.planCode.startsWith(
          'coach_',
        ) ==
        true;
  }

  bool _isProductForCurrentMembership(String productId) {
    final referralProductId = widget.referralProductId;
    if (referralProductId != null && productId != referralProductId) {
      return false;
    }
    return _isCoachProductId(productId) == _coachMembership;
  }

  Future<_RecoveryOutcome> _recoverActiveAppleSubscription({
    String? preferredProductId,
    required bool scheduleIntro,
  }) async {
    if (!Platform.isIOS || !InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      return _RecoveryOutcome.notFound;
    }

    late final List<AppleStoreKitEntitlementTransaction> transactions;
    try {
      final active = await AppleStoreKitEntitlementRecovery.activeTransactions(
        productIds: _knownProductIds,
      );
      transactions = AppleStoreKitEntitlementRecovery.prioritize(
        active
            .where(
              (transaction) =>
                  _isProductForCurrentMembership(transaction.productId),
            )
            .toList(growable: false),
        activeAt: DateTime.now().toUtc(),
        preferredProductId: preferredProductId,
      );
    } catch (_) {
      return _RecoveryOutcome.notFound;
    }
    if (transactions.isEmpty) return _RecoveryOutcome.notFound;

    final transaction = transactions.first;
    final preferredTransactionFound =
        preferredProductId == null ||
        transactions.any(
          (candidate) => candidate.productId == preferredProductId,
        );
    final entitlementCode = _entitlementCodeForProduct(transaction.productId);
    try {
      final entitlement = await AppleBillingService.verifyPurchase(
        productId: transaction.productId,
        signedTransaction: transaction.signedTransaction,
        entitlementCode: entitlementCode,
        // This is an entitlement recovery, not a new StoreKit purchase. Keep
        // the renewal state already reconciled by App Store notifications.
        reactivateAutoRenew: false,
        referralClaimToken: widget.referralClaimToken,
      );
      final active = await _acceptVerifiedEntitlement(
        entitlement,
        entitlementCode: entitlementCode,
        verifiedProductId: transaction.productId,
        enforceRequestedProduct: preferredTransactionFound,
      );
      if (!active) {
        _setStoreOperationIdle();
        if (_message == null) {
          _setMessage(_tr('subscription_apple_inactive_account'));
        }
        return _RecoveryOutcome.failed;
      }

      _setStoreOperationIdle();
      _setMessage(
        _tr('subscription_active_linked'),
        type: AppToastType.success,
      );
      if (widget.referralClaimToken != null && mounted) {
        Navigator.of(context).pop(true);
        return _RecoveryOutcome.activated;
      }
      if (widget.mandatory && mounted) {
        await _finishMandatorySubscription(scheduleIntro: scheduleIntro);
      }
      return _RecoveryOutcome.activated;
    } on AppleBillingException catch (error) {
      _setStoreOperationIdle();
      _setMessage(error.message);
      return _RecoveryOutcome.failed;
    } on TimeoutException {
      _setStoreOperationIdle();
      _setMessage(_tr('subscription_verification_timeout'));
      return _RecoveryOutcome.failed;
    } catch (_) {
      _setStoreOperationIdle();
      _setMessage(_tr('subscription_verification_failed'));
      return _RecoveryOutcome.failed;
    }
  }

  Future<_RecoveryOutcome> _recoverActiveGoogleSubscription({
    String? preferredProductId,
    required bool scheduleIntro,
  }) async {
    if (!Platform.isAndroid) return _RecoveryOutcome.notFound;

    late final List<PurchaseDetails> purchases;
    try {
      final addition = _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases().timeout(
        const Duration(seconds: 8),
      );
      if (response.error != null) return _RecoveryOutcome.notFound;
      purchases = response.pastPurchases
          .where(
            (purchase) =>
                _knownProductIds.contains(purchase.productID) &&
                _isProductForCurrentMembership(purchase.productID) &&
                (purchase.status == PurchaseStatus.purchased ||
                    purchase.status == PurchaseStatus.restored) &&
                purchase.verificationData.serverVerificationData
                    .trim()
                    .isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return _RecoveryOutcome.notFound;
    }
    if (purchases.isEmpty) return _RecoveryOutcome.notFound;

    purchases.sort((left, right) {
      final leftPreferred = left.productID == preferredProductId ? 1 : 0;
      final rightPreferred = right.productID == preferredProductId ? 1 : 0;
      final preferredOrder = rightPreferred.compareTo(leftPreferred);
      if (preferredOrder != 0) return preferredOrder;
      final leftDate = int.tryParse(left.transactionDate ?? '') ?? 0;
      final rightDate = int.tryParse(right.transactionDate ?? '') ?? 0;
      return rightDate.compareTo(leftDate);
    });

    final purchase = purchases.first;
    final preferredPurchaseFound =
        preferredProductId == null ||
        purchases.any((candidate) => candidate.productID == preferredProductId);
    try {
      final entitlementCode = _entitlementCodeForProduct(purchase.productID);
      final entitlement = await AppleBillingService.verifyGooglePurchase(
        productId: purchase.productID,
        purchaseToken: purchase.verificationData.serverVerificationData,
        entitlementCode: entitlementCode,
        replacementProductId: purchase.productID == _pendingReplacementProductId
            ? _pendingReplacementProductId
            : null,
        referralClaimToken: widget.referralClaimToken,
      );
      final active = await _acceptVerifiedEntitlement(
        entitlement,
        entitlementCode: entitlementCode,
        verifiedProductId: purchase.productID,
        enforceRequestedProduct: preferredPurchaseFound,
      );
      if (!active) {
        _setStoreOperationIdle();
        if (_message == null) {
          _setMessage(_tr('subscription_google_inactive_account'));
        }
        return _RecoveryOutcome.failed;
      }

      _setStoreOperationIdle();
      _setMessage(
        _tr('subscription_active_linked'),
        type: AppToastType.success,
      );
      if (widget.referralClaimToken != null && mounted) {
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        if (mounted) Navigator.of(context).pop(true);
        return _RecoveryOutcome.activated;
      }
      if (widget.mandatory && mounted) {
        await _finishMandatorySubscription(
          purchase: purchase,
          scheduleIntro: scheduleIntro,
        );
      } else if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      return _RecoveryOutcome.activated;
    } on AppleBillingException catch (error) {
      _setStoreOperationIdle();
      _setMessage(error.message);
      return _RecoveryOutcome.failed;
    } on TimeoutException {
      _setStoreOperationIdle();
      _setMessage(_tr('subscription_verification_timeout'));
      return _RecoveryOutcome.failed;
    } catch (_) {
      _setStoreOperationIdle();
      _setMessage(_tr('subscription_verification_failed'));
      return _RecoveryOutcome.failed;
    }
  }

  Future<void> _finishMandatorySubscription({
    PurchaseDetails? purchase,
    bool scheduleIntro = false,
  }) async {
    if (_mandatoryRouteFinished) return;
    _mandatoryRouteFinished = true;
    if (scheduleIntro) {
      await AccountStorage.schedulePostPurchaseIntro();
    }
    await AccountStorage.setVerifiedSubscriptionAccess(
      required: false,
      expiresAt: _billingState?.expiresAt,
    );
    if (purchase?.pendingCompletePurchase == true) {
      unawaited(_completePurchaseInBackground(purchase!));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<bool> _resumeExistingMandatorySubscription() async {
    if (!widget.mandatory) return false;
    final active = await _performSubscriptionActivation();
    if (!active) return false;
    await _finishMandatorySubscription();
    return true;
  }

  Future<void> _subscribe() async {
    final productId = _selectedProductId;
    final product = productId == null ? null : _products[productId];
    if (product == null || _purchasePending) return;

    final activeProductId = await _refreshBillingStateForCheckout();
    if (!mounted || _billingPreflightFailed || !_purchaseAllowedOnThisStore()) {
      return;
    }
    if (activeProductId == product.id && _billingState?.active == true) {
      if (widget.mandatory) {
        // Coach plans include normal app access, so the app-wide entitlement
        // can report this coach product even when coach access has not been
        // linked yet. Only the entitlement required by this checkout may
        // dismiss a mandatory route.
        if (await _resumeExistingMandatorySubscription()) return;
        if (!mounted) return;
      } else {
        _setMessage(
          _tr('subscription_already_active'),
          type: AppToastType.info,
        );
        return;
      }
    }

    if (_isStudentProduct(product.id)) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const EmailVerificationPage(studentPlanVerification: true),
        ),
      );
      if (!mounted || verified != true) return;
    }

    GoogleSubscriptionChange? change;
    ChangeSubscriptionParam? changeParam;
    if (Platform.isAndroid) {
      try {
        if (widget.referralClaimToken != null) {
          if (activeProductId != product.id) {
            _setMessage(_tr('subscription_referral_active_only'));
            return;
          }
          change = GoogleSubscriptionChange(
            action: 'referral_reward',
            currentProductId: product.id,
            targetProductId: product.id,
            replacementMode: 'DEFERRED',
          );
        } else {
          change = await BillingApi.prepareGoogleSubscriptionChange(
            targetProductId: product.id,
          );
        }
        if (change.isAlreadySubscribed) {
          _setMessage(_tr('subscription_already_active'));
          return;
        }
        if (!change.isInitialPurchase) {
          changeParam = await _googleChangeSubscriptionParam(change);
        }
      } on BillingApiException catch (error) {
        _setMessage(error.message);
        return;
      } catch (_) {
        _setMessage(_tr('subscription_google_check_failed'));
        return;
      }
    }
    if (!mounted) return;

    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: change?.action == 'upgrade_to_coach'
          ? _tr('subscription_confirm_coach_upgrade')
          : change != null && !change.isInitialPurchase
          ? _tr('subscription_confirm_plan_change')
          : _tr('subscription_confirm_subscription'),
      message: _confirmationMessage(product, change),
      cancelLabel: _tr('cancel'),
      confirmLabel: _tr('subscription_continue'),
    );
    if (!confirmed || !mounted) return;

    final isPlanChange =
        activeProductId != null && activeProductId != product.id;

    setState(() {
      _purchasePending = true;
      _checkoutProductId = product.id;
      _pendingReplacementProductId = change?.isInitialPurchase == false
          ? product.id
          : null;
      _pendingChangeAction = change?.action;
      _message = null;
    });
    try {
      final purchaseParam = await _purchaseParam(
        product: product,
        googleChangeParam: changeParam,
      );
      final started = await _store.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (started) {
        _schedulePurchaseTimeout(
          product.id,
          planChange: isPlanChange && Platform.isIOS,
          currentPlanEndsAt: _activePlanEndsAt,
        );
        return;
      }
      if (!started && mounted) {
        setState(() {
          _purchasePending = false;
          _checkoutProductId = null;
        });
        _setMessage(
          _tr('subscription_store_start_failed', {'store': _storeName()}),
        );
      }
    } on AppleBillingException catch (error) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _checkoutProductId = null;
      });
      _setMessage(error.message);
    } catch (error) {
      final startError = _purchaseStartErrorMessage(error);
      if (error is PlatformException &&
          error.code == 'storekit_duplicate_product_object') {
        await _recoverUnfinishedAppleTransaction(product.id);
      }
      final errorCode = error is PlatformException ? error.code : '';
      if (_purchaseMayAlreadyBeOwned('$startError $errorCode')) {
        if (Platform.isIOS) {
          final outcome = await _recoverActiveAppleSubscription(
            preferredProductId: product.id,
            scheduleIntro: true,
          );
          if (outcome != _RecoveryOutcome.notFound) return;
        } else {
          final outcome = await _recoverActiveGoogleSubscription(
            preferredProductId: product.id,
            scheduleIntro: true,
          );
          if (outcome != _RecoveryOutcome.notFound) return;
        }
        await _restorePurchases(
          automatic: true,
          skipStorePreflight: true,
          emptyResultMessage: startError,
        );
        return;
      }
      _setStoreOperationIdle();
      _setMessage(startError);
    }
  }

  Future<bool> _recoverUnfinishedAppleTransaction(String productId) async {
    if (!Platform.isIOS || !InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) {
      return false;
    }

    try {
      final unfinished = await SK2Transaction.unfinishedTransactions().timeout(
        const Duration(seconds: 5),
      );
      var recovered = false;
      for (final transaction in unfinished) {
        if (transaction.productId != productId) continue;

        final signedTransaction = transaction.receiptData?.trim() ?? '';
        if (signedTransaction.isNotEmpty) {
          try {
            await AppleBillingService.verifyPurchase(
              productId: productId,
              signedTransaction: signedTransaction,
              entitlementCode: _coachMembership ? 'coach_tools' : 'app_full',
              reactivateAutoRenew: true,
              referralClaimToken: widget.referralClaimToken,
            );
          } catch (_) {
            // A transaction linked to another Taqa account must still be
            // finished locally so it cannot block this Apple ID forever.
            // Finishing does not grant an entitlement; the backend remains
            // the authority for account ownership.
          }
        }

        final transactionId = int.tryParse(transaction.id);
        if (transactionId == null) continue;
        await SK2Transaction.finish(transactionId);
        recovered = true;
      }
      return recovered;
    } catch (_) {
      return false;
    }
  }

  Future<ChangeSubscriptionParam> _googleChangeSubscriptionParam(
    GoogleSubscriptionChange change,
  ) async {
    final currentProductId = change.currentProductId;
    if (currentProductId == null) {
      throw BillingApiException(_tr('subscription_google_missing'));
    }
    final addition = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases().timeout(
      const Duration(seconds: 8),
    );
    if (response.error != null) {
      throw BillingApiException(
        response.error?.message ?? _tr('subscription_google_load_failed'),
      );
    }
    final oldPurchase = response.pastPurchases
        .where((purchase) => purchase.productID == currentProductId)
        .firstOrNull;
    if (oldPurchase == null) {
      throw BillingApiException(_tr('subscription_google_owner_account'));
    }
    final replacementMode = switch (change.replacementMode) {
      'CHARGE_PRORATED_PRICE' => ReplacementMode.chargeProratedPrice,
      'CHARGE_FULL_PRICE' => ReplacementMode.chargeFullPrice,
      'DEFERRED' => ReplacementMode.deferred,
      _ => throw BillingApiException(_tr('subscription_change_not_supported')),
    };
    return ChangeSubscriptionParam(
      oldPurchaseDetails: oldPurchase,
      replacementMode: replacementMode,
    );
  }

  String _confirmationMessage(
    ProductDetails product,
    GoogleSubscriptionChange? change,
  ) {
    if (change?.action == 'upgrade_to_coach') {
      return change?.replacementMode == 'CHARGE_FULL_PRICE'
          ? 'Upgrade to Taqa Coach now. Google Play will charge the displayed new-plan price and apply the remaining value from your current plan before you confirm.'
          : _tr('subscription_confirm_upgrade_body');
    }
    if (change?.action == 'downgrade_to_standard' ||
        change?.action == 'change_billing_period') {
      final effectiveDate = _googleChangeEffectiveDate(change?.effectiveAt);
      final timing = effectiveDate == null
          ? 'your current paid period ends'
          : effectiveDate;
      return 'Your current plan remains active until $timing. The new ${product.price} plan starts and is charged at the next renewal. Google Play will show the final terms before you confirm.';
    }
    if (change?.action == 'referral_reward') {
      return _tr('subscription_confirm_referral_body');
    }
    return _tr('subscription_confirm_purchase_body', {
      'price': product.price,
      'account': Platform.isAndroid ? 'Google Play' : 'Apple ID',
      'store': _storeName(),
    });
  }

  String? _googleChangeEffectiveDate(DateTime? value) {
    if (value == null) return null;
    return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
  }

  Future<String?> _refreshBillingStateForCheckout() async {
    _billingPreflightFailed = false;
    try {
      final entitlement = await AppleBillingService.fetchEntitlement(
        'app_full',
      );
      final activeProductId = _applyBillingState(entitlement);
      _activeProductLookup = Future<String?>.value(activeProductId);
      return activeProductId;
    } on AppleBillingException catch (error) {
      _billingPreflightFailed = true;
      _setMessage(error.message);
      return null;
    } catch (_) {
      _billingPreflightFailed = true;
      _setMessage(_tr('subscription_current_check_failed'));
      return null;
    }
  }

  String? _applyBillingState(AppleBillingEntitlement entitlement) {
    _billingState = entitlement;
    final currentStoreSubscription = entitlement.subscriptions
        .where((subscription) => subscription.platform == _storePlatform)
        .firstOrNull;
    _activePlanEndsAt =
        currentStoreSubscription?.expiresAt ??
        (entitlement.active ? entitlement.expiresAt : null);
    return currentStoreSubscription?.productId ??
        (entitlement.active ? entitlement.productId : null);
  }

  bool _purchaseAllowedOnThisStore() {
    final billingState = _billingState;
    if (billingState == null ||
        !billingState.hasActiveSubscriptionFromAnotherStore(_storePlatform)) {
      return true;
    }
    final otherPlatform = _storePlatform == 'apple' ? 'google' : 'apple';
    _setMessage(
      _tr('subscription_other_store_managed', {
        'otherStore': _storeName(otherPlatform),
        'store': _storeName(),
      }),
      type: AppToastType.info,
    );
    return false;
  }

  Future<PurchaseParam> _purchaseParam({
    required ProductDetails product,
    ChangeSubscriptionParam? googleChangeParam,
  }) async {
    if (!Platform.isAndroid) {
      final accountToken = await AppleBillingService.fetchAccountToken();
      final authorization = widget.appleOfferAuthorization;
      if (widget.referralClaimToken != null && authorization == null) {
        throw AppleBillingException(
          _tr('subscription_apple_referral_unavailable'),
        );
      }
      if (authorization != null) {
        if (authorization.offerId != widget.googleReferralOfferTag ||
            product.id != widget.referralProductId) {
          throw AppleBillingException(
            _tr('subscription_apple_referral_mismatch'),
          );
        }
        return Sk2PurchaseParam(
          productDetails: product,
          applicationUserName: accountToken,
          promotionalOffer: SK2PromotionalOffer(
            offerId: authorization.offerId,
            signature: SK2SubscriptionOfferSignature(
              keyID: authorization.keyId,
              nonce: authorization.nonce,
              timestamp: authorization.timestamp,
              signature: authorization.signature,
            ),
          ),
        );
      }
      return PurchaseParam(
        productDetails: product,
        applicationUserName: accountToken,
      );
    }

    var accountId = _googleAccountId;
    if (accountId == null || accountId.isEmpty) {
      final offerings = await AppleBillingService.fetchGoogleOfferings();
      accountId = offerings.obfuscatedAccountId;
      _googleAccountId = accountId;
      _googleProductIdsByPlanCode = offerings.productIdsByPlanCode;
      _googleOfferingsByProductId = offerings.productsById;
      _storeProductIds = offerings.productIds;
    }

    return GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: accountId,
      offerToken: product is GooglePlayProductDetails
          ? product.offerToken
          : null,
      changeSubscriptionParam: googleChangeParam,
    );
  }

  String get _storePlatform => Platform.isAndroid ? 'google' : 'apple';

  String _storeName([String? platform]) {
    return (platform ?? _storePlatform) == 'google'
        ? 'Google Play'
        : 'Apple App Store';
  }

  String _purchaseStartErrorMessage(Object error) {
    if (error is PlatformException) {
      if (error.code == 'storekit_duplicate_product_object') {
        return _tr('subscription_apple_finishing_previous');
      }
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) return message;
      if (error.code.trim().isNotEmpty) {
        return _tr('subscription_store_start_failed_code', {
          'store': _storeName(),
          'code': error.code,
        });
      }
    }
    return _tr('subscription_purchase_start_failed');
  }

  void _schedulePurchaseTimeout(
    String productId, {
    required bool planChange,
    required DateTime? currentPlanEndsAt,
  }) {
    final timeout = planChange
        ? const Duration(seconds: 6)
        : Platform.isIOS
        ? const Duration(seconds: 12)
        : const Duration(seconds: 20);
    Future<void>.delayed(timeout, () async {
      if (!mounted ||
          _mandatoryRouteFinished ||
          !_purchasePending ||
          _checkoutProductId != productId) {
        return;
      }
      if (planChange) {
        if (currentPlanEndsAt != null) {
          try {
            await AppleBillingService.savePendingSubscriptionChange(
              platform: 'ios',
              targetProductId: productId,
            );
          } catch (_) {
            // App Store notifications will reconcile the pending plan even if
            // this best-effort request is temporarily unavailable.
          }
        }
        if (!mounted) return;
        setState(() {
          _purchasePending = false;
          _checkoutProductId = null;
        });
        _setMessage(
          _deferredPlanChangeMessage(currentPlanEndsAt),
          type: AppToastType.info,
        );
        return;
      }
      if (Platform.isIOS) {
        final outcome = await _recoverActiveAppleSubscription(
          preferredProductId: productId,
          scheduleIntro: true,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      } else {
        final outcome = await _recoverActiveGoogleSubscription(
          preferredProductId: productId,
          scheduleIntro: true,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      }
      if (await _resumeExistingMandatorySubscription()) return;
      if (!mounted || _checkoutProductId != productId) return;
      final processingMessage = Platform.isAndroid
          ? _tr('subscription_google_processing')
          : _tr('subscription_apple_processing');
      setState(() {
        _purchasePending = false;
      });
      if (_message == null) {
        _setMessage(processingMessage, type: AppToastType.info);
      }
    });
  }

  String _deferredPlanChangeMessage(DateTime? currentPlanEndsAt) {
    if (currentPlanEndsAt == null) {
      return _tr('subscription_deferred_change');
    }

    final localEnd = currentPlanEndsAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localEnd);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localEnd),
    );
    return _tr('subscription_deferred_change_date', {
      'date': date,
      'time': time,
    });
  }

  bool _isStudentProduct(String productId) {
    return productId.toLowerCase().contains('student');
  }

  List<TaqaSubscriptionPlan> get _catalogPlans {
    final plans = !widget.allowPlanTypeSwitch && widget.plans != null
        ? widget.plans!
        : _coachMembership
        ? TaqaSubscriptionCatalog.coachPlans
        : TaqaSubscriptionCatalog.plans;
    final referralProductId = widget.referralProductId;
    if (referralProductId == null) return plans;
    return plans
        .where((plan) => _storeProductIdForPlan(plan) == referralProductId)
        .toList(growable: false);
  }

  String? _firstAvailableProductId() {
    for (final plan in _catalogPlans) {
      final productId = _storeProductIdForPlan(plan);
      if (_products.containsKey(productId)) return productId;
    }
    return null;
  }

  Map<String, ProductDetails> _selectStoreProducts(
    List<ProductDetails> candidates,
  ) {
    if (!Platform.isAndroid) {
      return {for (final product in candidates) product.id: product};
    }
    final selected = <String, ProductDetails>{};
    final scores = <String, int>{};
    for (final product in candidates) {
      if (product is! GooglePlayProductDetails ||
          product.subscriptionIndex == null) {
        continue;
      }
      final offering = _googleOfferingsByProductId[product.id];
      final details = product.productDetails.subscriptionOfferDetails;
      final index = product.subscriptionIndex!;
      if (offering == null || details == null || index >= details.length) {
        continue;
      }
      if (widget.referralProductId != null &&
          product.id != widget.referralProductId) {
        continue;
      }
      final offer = details[index];
      if (offering.basePlanId != null &&
          offer.basePlanId != offering.basePlanId) {
        continue;
      }
      final matchesReferral =
          widget.googleReferralOfferTag != null &&
          offer.offerTags.contains(widget.googleReferralOfferTag);
      if (widget.googleReferralOfferTag != null && !matchesReferral) continue;
      final matchesDefault =
          offering.defaultOfferTag != null &&
          offer.offerTags.contains(offering.defaultOfferTag);
      final isPlainBasePlan = offer.offerId == null;
      final score = matchesReferral
          ? 3
          : matchesDefault
          ? 2
          : (isPlainBasePlan ? 1 : 0);
      if (score == 0 || score <= (scores[product.id] ?? -1)) continue;
      selected[product.id] = product;
      scores[product.id] = score;
    }
    return selected;
  }

  Set<String> get _knownProductIds => _storeProductIds.isNotEmpty
      ? _storeProductIds
      : {
          ...TaqaSubscriptionCatalog.plans.map((plan) => plan.productId),
          ...TaqaSubscriptionCatalog.coachPlans.map((plan) => plan.productId),
        };

  String _storeProductIdForPlan(TaqaSubscriptionPlan plan) {
    if (!Platform.isAndroid) return plan.productId;
    return _googleProductIdsByPlanCode[_planCode(plan)] ?? plan.productId;
  }

  String _planCode(TaqaSubscriptionPlan plan) {
    if (plan == TaqaSubscriptionCatalog.monthly) return 'standard_monthly';
    if (plan == TaqaSubscriptionCatalog.annual) return 'standard_yearly';
    if (plan == TaqaSubscriptionCatalog.studentMonthly) {
      return 'student_monthly';
    }
    if (plan == TaqaSubscriptionCatalog.studentAnnual) {
      return 'student_yearly';
    }
    if (plan == TaqaSubscriptionCatalog.coachMonthly) return 'coach_monthly';
    return 'coach_yearly';
  }

  Future<void> _restorePurchases({
    bool automatic = false,
    bool skipStorePreflight = false,
    String? emptyResultMessage,
  }) async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _restoreRequested = true;
      if (!automatic) _message = null;
    });
    try {
      if (await _resumeExistingMandatorySubscription()) return;
      if (Platform.isIOS && !skipStorePreflight) {
        final outcome = await _recoverActiveAppleSubscription(
          preferredProductId: _checkoutProductId,
          scheduleIntro: false,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      } else if (Platform.isAndroid && !skipStorePreflight) {
        final outcome = await _recoverActiveGoogleSubscription(
          preferredProductId: _checkoutProductId,
          scheduleIntro: false,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      }
      final applicationUserName = await _storeAccountIdentifier();
      await _store
          .restorePurchases(applicationUserName: applicationUserName)
          .timeout(const Duration(seconds: 12));
      _scheduleRestoreTimeout(
        showMissingSubscriptionMessage: !automatic,
        emptyResultMessage: emptyResultMessage,
      );
    } on AppleBillingException catch (error) {
      if (!mounted) return;
      _setStoreOperationIdle();
      _setMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _setStoreOperationIdle();
      _setMessage(_tr('subscription_restore_failed'));
    }
  }

  void _scheduleRestoreTimeout({
    required bool showMissingSubscriptionMessage,
    String? emptyResultMessage,
  }) {
    Future<void>.delayed(const Duration(seconds: 12), () async {
      if (!mounted || !_restoring || _mandatoryRouteFinished) return;
      if (Platform.isIOS) {
        final outcome = await _recoverActiveAppleSubscription(
          preferredProductId: _checkoutProductId,
          scheduleIntro: false,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      } else if (Platform.isAndroid) {
        final outcome = await _recoverActiveGoogleSubscription(
          preferredProductId: _checkoutProductId,
          scheduleIntro: false,
        );
        if (outcome != _RecoveryOutcome.notFound) return;
      }
      if (await _resumeExistingMandatorySubscription()) return;
      if (!mounted || !_restoring) return;
      String? resultMessage;
      setState(() {
        _restoring = false;
        _purchasePending = false;
        _checkoutProductId = null;
        _restoreRequested = false;
        if (emptyResultMessage != null) {
          _message = emptyResultMessage;
          resultMessage = emptyResultMessage;
        } else if (showMissingSubscriptionMessage) {
          _message ??= _tr('subscription_none_found', {
            'account': Platform.isAndroid ? 'Google Play' : 'Apple ID',
          });
          resultMessage = _message;
        }
      });
      if (resultMessage != null) {
        _showToast(
          resultMessage!,
          type: emptyResultMessage == null
              ? AppToastType.info
              : AppToastType.error,
        );
      }
    });
  }

  Future<String> _storeAccountIdentifier() async {
    if (!Platform.isAndroid) {
      return AppleBillingService.fetchAccountToken();
    }
    final existing = _googleAccountId;
    if (existing != null && existing.isNotEmpty) return existing;
    final offerings = await AppleBillingService.fetchGoogleOfferings();
    _googleAccountId = offerings.obfuscatedAccountId;
    _googleProductIdsByPlanCode = offerings.productIdsByPlanCode;
    _googleOfferingsByProductId = offerings.productsById;
    _storeProductIds = offerings.productIds;
    return offerings.obfuscatedAccountId;
  }

  Future<void> _openLegalLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      _setMessage(_tr('subscription_legal_unavailable'));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _setMessage(_tr('subscription_legal_open_failed'));
  }

  Future<void> _showAccountActions() async {
    if (_accountActionInProgress || _purchasePending || _restoring) return;
    final t = AppLocalizations.of(context);
    final action = await showTaqaOptionDialog<_SubscriptionAccountAction>(
      context: context,
      title: t.translate('subscription_account_actions_title'),
      cancelLabel: t.translate('cancel'),
      options: [
        TaqaDialogOption(
          value: _SubscriptionAccountAction.freeze,
          title: t.translate('subscription_freeze_account'),
          subtitle: t.translate('subscription_freeze_account_sub'),
        ),
        TaqaDialogOption(
          value: _SubscriptionAccountAction.delete,
          title: t.translate('settings_delete_account'),
          subtitle: t.translate('settings_delete_account_sub'),
        ),
        TaqaDialogOption(
          value: _SubscriptionAccountAction.logout,
          title: t.translate('subscription_sign_out'),
          subtitle: t.translate('subscription_sign_out_sub'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == _SubscriptionAccountAction.logout) {
      await _logout();
      return;
    }
    await _confirmAccountAction(action);
  }

  Future<void> _confirmAccountAction(_SubscriptionAccountAction action) async {
    if (_accountActionInProgress) return;
    final t = AppLocalizations.of(context);
    final freeze = action == _SubscriptionAccountAction.freeze;
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: freeze
          ? t.translate('subscription_freeze_account')
          : t.translate('settings_delete_account'),
      message: freeze
          ? t.translate('settings_deactivate_account_confirm_body')
          : t.translate('settings_delete_account_confirm_body'),
      cancelLabel: t.translate('cancel'),
      confirmLabel: freeze
          ? t.translate('subscription_freeze_account')
          : t.translate('settings_delete_account_confirm_yes'),
    );
    if (!confirmed || !mounted) return;

    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    if (userId == null || userId <= 0) {
      _showToast(t.translate('user_missing'));
      return;
    }

    setState(() => _accountActionInProgress = true);
    try {
      final result = freeze
          ? await ProfileApi.deactivateAccount(userId)
          : await ProfileApi.deleteAccount(userId);
      if (!freeze) await AccountStorage.clear();
      await NotificationService.refreshDailyJournalRemindersForCurrentUser();
      if (!mounted) return;

      final serverMessage = result['message']?.toString().trim() ?? '';
      _showToast(
        serverMessage.isNotEmpty
            ? serverMessage
            : freeze
            ? t.translate('settings_deactivate_account_success')
            : t.translate('settings_delete_account_success'),
        type: AppToastType.success,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showToast(
        userFriendlyErrorMessage(
          error,
          fallback: t.translate('subscription_account_action_failed'),
        ),
      );
    } finally {
      if (mounted) setState(() => _accountActionInProgress = false);
    }
  }

  Future<void> _logout() async {
    final userId = await AccountStorage.getUserId();
    await RemotePushService.unregisterTokenForCurrentUser();
    await NotificationService.cancelAccountNotifications(userId: userId);
    await AccountStorage.logoutSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final selectedProduct = _selectedProductId == null
        ? null
        : _products[_selectedProductId];
    final availablePlans = _catalogPlans
        .where((plan) => _products.containsKey(_storeProductIdForPlan(plan)))
        .toList(growable: false);
    final canSubscribe =
        selectedProduct != null &&
        _storeAvailable &&
        !_loading &&
        !_purchasePending &&
        !_restoring &&
        !_accountActionInProgress;
    final canChoosePlan = !_loading && availablePlans.isNotEmpty;
    final operationInProgress =
        _purchasePending || _restoring || _accountActionInProgress;

    return PopScope(
      canPop: !widget.mandatory || widget.allowBackNavigation,
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        appBar: TaqaPageAppBar(
          title: t.translate('subscription_page_title'),
          showBackButton: !widget.mandatory || widget.allowBackNavigation,
          trailing: IconButton(
            tooltip: widget.mandatory
                ? t.translate('subscription_account_actions_title')
                : t.translate('subscription_sign_out'),
            onPressed: operationInProgress
                ? null
                : widget.mandatory
                ? _showAccountActions
                : _logout,
            icon: Icon(
              widget.mandatory ? Icons.more_vert_rounded : Icons.logout_rounded,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: operationInProgress,
                child: ListView(
                  padding: TaqaUiScale.insetsLTRB(16, 20, 16, 28),
                  children: [
                    Text(
                      _coachMembership
                          ? t.translate('subscription_coach_membership_title')
                          : t.translate('subscription_membership_title'),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(25),
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      _coachMembership
                          ? t.translate('subscription_coach_membership_body')
                          : widget.mandatory
                          ? t.translate('subscription_ready_body')
                          : t.translate('subscription_membership_body'),
                      style: _bodyStyle,
                    ),
                    if (widget.allowPlanTypeSwitch && _coachPlanAvailable) ...[
                      SizedBox(height: TaqaUiScale.h(16)),
                      Row(
                        children: [
                          Expanded(
                            child: IgnorePointer(
                              ignoring:
                                  _loading || _purchasePending || _restoring,
                              child: Opacity(
                                opacity:
                                    _loading || _purchasePending || _restoring
                                    ? 0.55
                                    : 1,
                                child: TaqaRangeTab(
                                  label: t.translate(
                                    'subscription_normal_plans',
                                  ),
                                  selected: !_coachMembership,
                                  onTap: () => _selectMembershipType(false),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: TaqaUiScale.w(10)),
                          Expanded(
                            child: IgnorePointer(
                              ignoring:
                                  _loading || _purchasePending || _restoring,
                              child: Opacity(
                                opacity:
                                    _loading || _purchasePending || _restoring
                                    ? 0.55
                                    : 1,
                                child: TaqaRangeTab(
                                  label: t.translate(
                                    'subscription_coach_plans',
                                  ),
                                  selected: _coachMembership,
                                  onTap: () => _selectMembershipType(true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: TaqaUiScale.h(16)),
                    _PremiumOverviewCard(
                      selectedProduct: selectedProduct,
                      coachMembership: _coachMembership,
                      onChoosePlan: canChoosePlan
                          ? () => _showPlanPicker(availablePlans)
                          : null,
                    ),
                    SizedBox(height: TaqaUiScale.h(16)),
                    TaqaFilledButton(
                      label: selectedProduct == null
                          ? t.translate('subscription_choose_a_plan')
                          : _tr('subscription_subscribe_for', {
                              'price': selectedProduct.price,
                            }),
                      onTap: canSubscribe ? _subscribe : null,
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    TextButton(
                      onPressed: _storeAvailable && !operationInProgress
                          ? _restorePurchases
                          : null,
                      child: Text(
                        t.translate('subscription_restore_purchases'),
                        style: _linkStyle,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      _tr('subscription_payment_disclaimer', {
                        'account': Platform.isAndroid
                            ? 'Google Play'
                            : 'Apple ID',
                        'store': _storeName(),
                      }),
                      style: _bodyStyle,
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    _LegalLinks(onOpen: _openLegalLink),
                  ],
                ),
              ),
              if (operationInProgress)
                const Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(child: TaqaRefreshSpinner()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(TaqaSubscriptionPlan plan) {
    final productId = _storeProductIdForPlan(plan);
    final product = _products[productId];
    return TaqaSubscriptionPlanCard(
      title: _planTitle(plan),
      period: _planPeriod(plan),
      price: product?.price ?? '',
      description: _planDescription(plan),
      student:
          plan == TaqaSubscriptionCatalog.studentMonthly ||
          plan == TaqaSubscriptionCatalog.studentAnnual,
      selected: productId == _selectedProductId,
      onTap: product == null
          ? null
          : () => setState(() {
              _selectedProductId = productId;
              _message = null;
            }),
    );
  }

  String _planDescription(TaqaSubscriptionPlan plan) {
    final student =
        plan == TaqaSubscriptionCatalog.studentMonthly ||
        plan == TaqaSubscriptionCatalog.studentAnnual;
    final annual =
        plan == TaqaSubscriptionCatalog.annual ||
        plan == TaqaSubscriptionCatalog.studentAnnual;
    if (student && annual) {
      return _tr('subscription_student_annual_description');
    }
    if (student) {
      return _tr('subscription_student_monthly_description');
    }
    if (annual) return _tr('subscription_annual_description');
    return _tr('subscription_monthly_description');
  }

  String _planTitle(TaqaSubscriptionPlan plan) {
    if (plan == TaqaSubscriptionCatalog.monthly) {
      return _tr('subscription_plan_standard_monthly');
    }
    if (plan == TaqaSubscriptionCatalog.annual) {
      return _tr('subscription_plan_standard_annual');
    }
    if (plan == TaqaSubscriptionCatalog.studentMonthly) {
      return _tr('subscription_plan_student_monthly');
    }
    if (plan == TaqaSubscriptionCatalog.studentAnnual) {
      return _tr('subscription_plan_student_annual');
    }
    if (plan == TaqaSubscriptionCatalog.coachMonthly) {
      return _tr('subscription_plan_coach_monthly');
    }
    return _tr('subscription_plan_coach_annual');
  }

  String _planPeriod(TaqaSubscriptionPlan plan) {
    final annual =
        plan == TaqaSubscriptionCatalog.annual ||
        plan == TaqaSubscriptionCatalog.studentAnnual ||
        plan == TaqaSubscriptionCatalog.coachAnnual;
    return _tr(
      annual ? 'subscription_period_annual' : 'subscription_period_monthly',
    );
  }

  Future<void> _showPlanPicker(List<TaqaSubscriptionPlan> plans) async {
    await TaqaPopupGuard.generalDialogVoid(
      context: context,
      barrierLabel: _tr('subscription_close_plan_selection'),
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, _) => _PlanPickerOverlay(
        plans: plans,
        cardBuilder: _buildPlanCard,
        onSelected: (plan) {
          setState(() {
            _selectedProductId = _storeProductIdForPlan(plan);
            _message = null;
          });
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  TextStyle get _bodyStyle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(13),
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
  );

  TextStyle get _linkStyle => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(13),
    fontWeight: FontWeight.w700,
    color: TaqaUiColors.charcoal,
  );
}

class _PremiumOverviewCard extends StatelessWidget {
  const _PremiumOverviewCard({
    required this.selectedProduct,
    required this.coachMembership,
    required this.onChoosePlan,
  });

  final ProductDetails? selectedProduct;
  final bool coachMembership;
  final VoidCallback? onChoosePlan;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final selectedPrice = selectedProduct?.price;
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: TaqaUiColors.charcoal,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coachMembership
                ? t.translate('subscription_everything_coach')
                : t.translate('subscription_everything_standard'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.white,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(6)),
          Text(
            coachMembership
                ? t.translate('subscription_coach_overview_body')
                : t.translate('subscription_standard_overview_body'),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              color: TaqaUiColors.white.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          if (coachMembership)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_0'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_1'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_2'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_3'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_4'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_coach_feature_5'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_1'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_2'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_3'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_4'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_5'),
                ),
                _PremiumFeatureBullet(
                  label: t.translate('subscription_standard_feature_6'),
                ),
              ],
            ),
          SizedBox(height: TaqaUiScale.h(18)),
          _PlanChoiceButton(
            label: selectedPrice == null
                ? t.translate('subscription_choose_plan')
                : t
                      .translate('subscription_change_plan')
                      .replaceAll('{price}', selectedPrice),
            onTap: onChoosePlan,
          ),
        ],
      ),
    );
  }
}

class _PremiumFeatureBullet extends StatelessWidget {
  const _PremiumFeatureBullet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: TaqaUiScale.h(5)),
            child: Container(
              width: TaqaUiScale.w(5),
              height: TaqaUiScale.h(5),
              decoration: const BoxDecoration(
                color: TaqaUiColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: TaqaUiScale.w(9)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: TaqaUiColors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChoiceButton extends StatelessWidget {
  const _PlanChoiceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.accent,
      borderRadius: TaqaUiScale.radius(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: TaqaUiScale.radius(7),
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(46),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanPickerOverlay extends StatelessWidget {
  const _PlanPickerOverlay({
    required this.plans,
    required this.cardBuilder,
    required this.onSelected,
  });

  final List<TaqaSubscriptionPlan> plans;
  final Widget Function(TaqaSubscriptionPlan plan) cardBuilder;
  final ValueChanged<TaqaSubscriptionPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: ColoredBox(
                color: TaqaUiColors.charcoal.withValues(alpha: 0.28),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Material(
                  color: TaqaUiColors.lightGray,
                  borderRadius: TaqaUiScale.radius(24),
                  child: Container(
                    padding: TaqaUiScale.insetsLTRB(16, 14, 16, 18),
                    decoration: BoxDecoration(
                      borderRadius: TaqaUiScale.radius(24),
                      border: Border.all(
                        color: TaqaUiColors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.translate('subscription_choose_your_plan'),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(21),
                                  fontWeight: FontWeight.w700,
                                  color: TaqaUiColors.charcoal,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: TaqaUiColors.charcoal,
                              tooltip: t.translate('subscription_close'),
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(2)),
                        Text(
                          t.translate('subscription_plan_picker_body'),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(13),
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(16)),
                        SizedBox(
                          height: TaqaUiScale.h(238),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: plans.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(width: TaqaUiScale.w(12)),
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              return SizedBox(
                                width: TaqaUiScale.w(292),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: TaqaUiScale.radius(15),
                                  child: InkWell(
                                    onTap: () => onSelected(plan),
                                    borderRadius: TaqaUiScale.radius(15),
                                    child: IgnorePointer(
                                      child: cardBuilder(plan),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: TaqaUiColors.charcoal,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final linkStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(13),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TaqaUiScale.w(10),
      children: [
        TextButton(
          onPressed: () => onOpen(TaqaSubscriptionCatalog.termsOfUseUrl),
          style: buttonStyle,
          child: Text(
            t.translate('subscription_terms_of_use'),
            style: linkStyle,
          ),
        ),
        Text(
          '·',
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
          ),
        ),
        TextButton(
          onPressed: () => onOpen(TaqaSubscriptionCatalog.privacyPolicyUrl),
          style: buttonStyle,
          child: Text(
            t.translate('subscription_privacy_policy'),
            style: linkStyle,
          ),
        ),
      ],
    );
  }
}
