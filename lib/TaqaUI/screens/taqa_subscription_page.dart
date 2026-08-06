import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/email_verification_page.dart';
import '../../core/account_storage.dart';
import '../../screens/welcome.dart';
import '../../services/core/notification_service.dart';
import '../../services/auth/profile_service.dart';
import '../../services/purchases/apple_billing_service.dart';
import '../../services/purchases/taqa_subscription_catalog.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_filled_button.dart';
import '../components/taqa_page_app_bar.dart';
import '../components/taqa_refresh_indicator.dart';
import '../components/taqa_subscription_plan_card.dart';
import '../components/taqa_steps_ui.dart' show TaqaRangeTab;
import '../components/taqa_toast.dart';
import '../components/taqa_value_dialog.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Taqa Fitness subscriptions purchased through the App Store / StoreKit.
class TaqaSubscriptionPage extends StatefulWidget {
  const TaqaSubscriptionPage({
    super.key,
    this.mandatory = false,
    this.plans,
    this.coachMembership = false,
    this.allowPlanTypeSwitch = true,
    this.allowBackNavigation = false,
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
  String? _checkoutProductId;
  bool _restoreRequested = false;
  bool _mandatoryRouteFinished = false;
  String? _selectedProductId;
  String? _message;
  late bool _coachMembership;
  bool _coachPlanAvailable = false;
  Future<String?>? _activeProductLookup;
  DateTime? _activePlanEndsAt;
  AppleBillingEntitlement? _billingState;
  bool _billingPreflightFailed = false;
  String? _googleAccountId;
  Map<String, String> _googleProductIdsByPlanCode = const {};
  Set<String> _storeProductIds = const {};

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
        productIds = offerings.productIds;
      }
      _storeProductIds = productIds;
      final response = await _store.queryProductDetails(productIds);
      if (!mounted) return;
      String? storeMessage;
      setState(() {
        _storeAvailable = true;
        _products
          ..clear()
          ..addEntries(
            response.productDetails.map(
              (product) => MapEntry(product.id, product),
            ),
          );
        _selectedProductId =
            _catalogPlans
                .map(_storeProductIdForPlan)
                .contains(_selectedProductId)
            ? _selectedProductId
            : _firstAvailableProductId();
        _message = response.error?.message;
        if (_products.isEmpty && response.notFoundIDs.isNotEmpty) {
          _message =
              'Subscriptions are not available from the App Store yet. Please try again soon.';
        }
        storeMessage = _message;
        _loading = false;
      });
      if (storeMessage != null) _showToast(storeMessage!);
    } catch (_) {
      _setStoreUnavailable();
    }
  }

  void _setStoreUnavailable() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _storeAvailable = false;
      _message = null;
    });
    _setMessage('${_storeName()} is unavailable. Please try again later.');
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
    setState(() {
      _purchasePending = false;
      _restoring = false;
      _checkoutProductId = null;
      _restoreRequested = false;
      _message = null;
    });
    _setMessage('The App Store could not process the purchase.');
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
        // StoreKit can report its "currently subscribed" alert as either an
        // error or a cancellation. Recover from both by asking for current
        // entitlements, but retain the original result if none are returned.
        await _restorePurchases(
          automatic: true,
          emptyResultMessage: _purchaseErrorMessage(purchase),
        );
        return;
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _purchasePending = false;
            _restoring = false;
            _checkoutProductId = null;
            _restoreRequested = false;
          });
          _setMessage('The purchase was canceled.', type: AppToastType.info);
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
          setState(() {
            _purchasePending = false;
            _restoring = false;
            _checkoutProductId = null;
            _restoreRequested = false;
          });
          if (existingMessage == null) {
            _setMessage(
              _coachMembership
                  ? 'We could not verify an active coach subscription. Please try Restore Purchases.'
                  : 'We could not verify an active subscription. Please try Restore Purchases.',
            );
          }
          continue;
        }
        _setMessage(
          purchase.status == PurchaseStatus.restored
              ? 'Your subscription has been restored and linked.'
              : 'Your subscription is active and linked.',
          type: AppToastType.success,
        );
        if (widget.mandatory && mounted) {
          await _finishMandatorySubscription(purchase: purchase);
          return;
        }
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (mounted) {
        setState(() {
          _purchasePending = false;
          _restoring = false;
          _checkoutProductId = null;
          _restoreRequested = false;
        });
      }
    }
  }

  bool _isExpectedPurchaseUpdate(PurchaseDetails purchase) {
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
    return message.isNotEmpty
        ? message
        : 'The purchase could not be completed. Please try again.';
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
    try {
      final entitlementCode = _coachMembership ? 'coach_tools' : 'app_full';
      final entitlement = purchase == null
          ? await AppleBillingService.fetchEntitlement(entitlementCode)
          : Platform.isAndroid
          ? await AppleBillingService.verifyGooglePurchase(
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
              entitlementCode: entitlementCode,
            )
          : await AppleBillingService.verifyPurchase(
              productId: purchase.productID,
              signedTransaction:
                  purchase.verificationData.serverVerificationData,
              entitlementCode: entitlementCode,
            );
      if (!entitlement.active) return false;
      final requestedProductId = _checkoutProductId;
      final verifiedProductId =
          purchase?.productID ?? entitlement.productId ?? '';
      if (requestedProductId != null &&
          requestedProductId != verifiedProductId) {
        _setMessage(
          'Your current plan is still active. Apple has not activated the selected plan yet. A switch to a lower plan takes effect at the next renewal.',
          type: AppToastType.info,
        );
        return false;
      }
      if (_coachMembership) {
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
    } on AppleBillingException catch (error) {
      _setMessage(error.message);
      return false;
    } on TimeoutException {
      _setMessage(
        'Subscription verification timed out. Please try Restore Purchases.',
      );
      return false;
    } catch (_) {
      _setMessage(
        'Your subscription could not be verified. Please try Restore Purchases.',
      );
      return false;
    }
  }

  Future<void> _finishMandatorySubscription({PurchaseDetails? purchase}) async {
    if (_mandatoryRouteFinished) return;
    _mandatoryRouteFinished = true;
    await AccountStorage.setSubscriptionRequired(false);
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

    if (_isStudentProduct(product.id)) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const EmailVerificationPage(studentPlanVerification: true),
        ),
      );
      if (!mounted || verified != true) return;
    }

    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: 'Confirm subscription',
      message:
          'Subscribe for ${product.price}. Your ${Platform.isAndroid ? 'Google Play account' : 'Apple ID'} will be charged when you confirm in ${_storeName()}.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !mounted) return;

    final isPlanChange =
        activeProductId != null && activeProductId != product.id;

    setState(() {
      _purchasePending = true;
      _checkoutProductId = product.id;
      _message = null;
    });
    try {
      final purchaseParam = await _purchaseParam(
        product: product,
        activeProductId: activeProductId,
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
        _setMessage('${_storeName()} could not start the purchase.');
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
      if (await _resumeExistingMandatorySubscription()) return;
      await _restorePurchases(automatic: true, emptyResultMessage: startError);
      if (_restoring || _mandatoryRouteFinished) return;
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _checkoutProductId = null;
      });
      _setMessage(startError);
    }
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
      _setMessage(
        'Your current subscription could not be checked. Please try again.',
      );
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
      'Your active subscription is managed through ${_storeName(otherPlatform)}. '
      'To prevent two renewals, keep using Taqa with that plan and subscribe '
      'through ${_storeName()} only after it ends.',
      type: AppToastType.info,
    );
    return false;
  }

  Future<PurchaseParam> _purchaseParam({
    required ProductDetails product,
    required String? activeProductId,
  }) async {
    if (!Platform.isAndroid) {
      final accountToken = await AppleBillingService.fetchAccountToken();
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
      _storeProductIds = offerings.productIds;
    }

    ChangeSubscriptionParam? changeSubscriptionParam;
    if (activeProductId != null && activeProductId != product.id) {
      final addition = _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final previous = await addition.queryPastPurchases(
        applicationUserName: accountId,
      );
      final oldPurchase = previous.pastPurchases
          .where((purchase) => purchase.productID == activeProductId)
          .firstOrNull;
      if (oldPurchase == null) {
        throw const AppleBillingException(
          'Sign in to the Google Play account used for your current plan '
          'before changing it.',
        );
      }
      changeSubscriptionParam = ChangeSubscriptionParam(
        oldPurchaseDetails: oldPurchase,
        replacementMode: ReplacementMode.withTimeProration,
      );
    }
    return GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: accountId,
      changeSubscriptionParam: changeSubscriptionParam,
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
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) return message;
      if (error.code.trim().isNotEmpty) {
        return 'The App Store could not start the purchase (${error.code}).';
      }
    }
    return 'The purchase could not be started. Please try again.';
  }

  void _schedulePurchaseTimeout(
    String productId, {
    required bool planChange,
    required DateTime? currentPlanEndsAt,
  }) {
    Future<void>.delayed(Duration(seconds: planChange ? 6 : 30), () async {
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
      if (await _resumeExistingMandatorySubscription()) return;
      if (!mounted || _checkoutProductId != productId) return;
      final processingMessage =
          'Apple is still processing the purchase. Try Restore Purchases to continue.';
      setState(() {
        _purchasePending = false;
        _checkoutProductId = null;
      });
      if (_message == null) {
        _setMessage(processingMessage, type: AppToastType.info);
      }
    });
  }

  String _deferredPlanChangeMessage(DateTime? currentPlanEndsAt) {
    if (currentPlanEndsAt == null) {
      return 'Your current plan stays active until the next renewal. '
          'The selected plan will start then.';
    }

    final localEnd = currentPlanEndsAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localEnd);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localEnd),
    );
    return 'Your current plan stays active until $date at $time. '
        'The selected plan will start at the next renewal.';
  }

  bool _isStudentProduct(String productId) {
    return productId.toLowerCase().contains('student');
  }

  List<TaqaSubscriptionPlan> get _catalogPlans {
    if (!widget.allowPlanTypeSwitch && widget.plans != null) {
      return widget.plans!;
    }
    return _coachMembership
        ? TaqaSubscriptionCatalog.coachPlans
        : TaqaSubscriptionCatalog.plans;
  }

  String? _firstAvailableProductId() {
    for (final plan in _catalogPlans) {
      final productId = _storeProductIdForPlan(plan);
      if (_products.containsKey(productId)) return productId;
    }
    return null;
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
      final applicationUserName = await _storeAccountIdentifier();
      await _store.restorePurchases(applicationUserName: applicationUserName);
      _scheduleRestoreTimeout(
        showMissingSubscriptionMessage: !automatic,
        emptyResultMessage: emptyResultMessage,
      );
    } on AppleBillingException catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _purchasePending = false;
        _checkoutProductId = null;
        _restoreRequested = false;
      });
      _setMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _purchasePending = false;
        _checkoutProductId = null;
        _restoreRequested = false;
      });
      _setMessage('Purchases could not be restored. Please try again.');
    }
  }

  void _scheduleRestoreTimeout({
    required bool showMissingSubscriptionMessage,
    String? emptyResultMessage,
  }) {
    Future<void>.delayed(const Duration(seconds: 15), () async {
      if (!mounted || !_restoring || _mandatoryRouteFinished) return;
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
          _message ??=
              'No active subscription was found. Check that you are signed in '
              'with the ${Platform.isAndroid ? 'Google Play account' : 'Apple ID'} used to subscribe.';
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
    _storeProductIds = offerings.productIds;
    return offerings.obfuscatedAccountId;
  }

  Future<void> _openLegalLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      _setMessage('This legal page is not available right now.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _setMessage('This legal page could not be opened.');
  }

  Future<void> _logout() async {
    await AccountStorage.logoutSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage(fromLogout: true)),
      (route) => false,
    );
    NotificationService.refreshDailyJournalRemindersForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
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
        !_restoring;
    final canChoosePlan = !_loading && availablePlans.isNotEmpty;
    final operationInProgress = _purchasePending || _restoring;

    return PopScope(
      canPop: !widget.mandatory || widget.allowBackNavigation,
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        appBar: TaqaPageAppBar(
          title: 'Subscriptions',
          showBackButton: !widget.mandatory || widget.allowBackNavigation,
          trailing: IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
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
                          ? 'Taqa Coach Membership'
                          : 'Taqa Subscription',
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
                          ? 'Start your membership to access your coach tools.'
                          : widget.mandatory
                          ? 'Your plan is ready. Subscribe to unlock it.'
                          : 'One membership for your full Taqa Subscription experience.',
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
                                  label: 'Normal plans',
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
                                  label: 'Coach plans',
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
                          ? 'Choose a plan'
                          : 'Subscribe for ${selectedProduct.price}',
                      onTap: canSubscribe ? _subscribe : null,
                    ),
                    SizedBox(height: TaqaUiScale.h(6)),
                    TextButton(
                      onPressed: _storeAvailable && !operationInProgress
                          ? _restorePurchases
                          : null,
                      child: Text('Restore Purchases', style: _linkStyle),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      'Payment will be charged to your ${Platform.isAndroid ? 'Google Play account' : 'Apple ID'} when you confirm. '
                      'Your subscription automatically renews unless you cancel at '
                      'least 24 hours before the end of the current period. You can '
                      'manage or cancel it in your ${_storeName()} account settings.',
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
      title: plan.title,
      period: plan.periodLabel,
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
      return 'Full access with student pricing, billed annually.';
    }
    if (student) {
      return 'Full access with student pricing, billed monthly.';
    }
    if (annual) return 'Full Taqa Subscription access, billed annually.';
    return 'Full Taqa Subscription access, billed monthly.';
  }

  Future<void> _showPlanPicker(List<TaqaSubscriptionPlan> plans) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Close plan selection',
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
                ? 'Everything in Taqa Coach'
                : 'Everything in Taqa Subscription',
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
                ? 'The tools you need to coach clients, review their progress and grow your practice.'
                : 'One membership, all the tools you need to train with intent.',
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumFeatureBullet(
                  label: 'Create and manage personalised training plans',
                ),
                _PremiumFeatureBullet(
                  label: 'Review client progress, feedback and check-ins',
                ),
                _PremiumFeatureBullet(
                  label:
                      'Message clients and manage your coaching relationships',
                ),
                _PremiumFeatureBullet(
                  label: 'Access coach dashboards and client insights',
                ),
                _PremiumFeatureBullet(
                  label:
                      'Share your referral code—referred coaches get \$1 off their first month',
                ),
              ],
            )
          else
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumFeatureBullet(
                  label: 'Personalised training plans and workout logging',
                ),
                _PremiumFeatureBullet(
                  label: 'Nutrition guidance, meal tracking and daily targets',
                ),
                _PremiumFeatureBullet(
                  label: 'Progress, recovery and wearable health insights',
                ),
                _PremiumFeatureBullet(
                  label: 'Message your coach and receive feedback',
                ),
                _PremiumFeatureBullet(
                  label: 'Connect with the Taqa Fitness community',
                ),
                _PremiumFeatureBullet(label: 'And more!'),
              ],
            ),
          SizedBox(height: TaqaUiScale.h(18)),
          _PlanChoiceButton(
            label: selectedPrice == null
                ? 'Choose plan'
                : 'Change plan · $selectedPrice',
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
                                'Choose your plan',
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
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(2)),
                        Text(
                          'Every plan includes the same Taqa Subscription features. Tap a plan to select it.',
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
          child: Text('Terms of Use', style: linkStyle),
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
          child: Text('Privacy Policy', style: linkStyle),
        ),
      ],
    );
  }
}
