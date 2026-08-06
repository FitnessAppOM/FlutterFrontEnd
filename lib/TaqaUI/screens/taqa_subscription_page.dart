import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/email_verification_page.dart';
import '../../core/account_storage.dart';
import '../../screens/welcome.dart';
import '../../services/core/notification_service.dart';
import '../../services/purchases/billing_api.dart';
import '../../services/purchases/taqa_subscription_catalog.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_filled_button.dart';
import '../components/taqa_page_app_bar.dart';
import '../components/taqa_subscription_plan_card.dart';
import '../components/taqa_value_dialog.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Taqa Fitness subscriptions purchased through the platform store.
class TaqaSubscriptionPage extends StatefulWidget {
  const TaqaSubscriptionPage({
    super.key,
    this.mandatory = false,
    this.plans,
    this.coachMembership = false,
  });

  /// When opened after onboarding, the user must subscribe or restore a
  /// subscription before the app can continue to their generated plan.
  final bool mandatory;

  /// Limits checkout to a particular subscription offering, such as the
  /// coach membership.
  final List<TaqaSubscriptionPlan>? plans;

  /// Marks a completed StoreKit transaction as an active coach membership.
  final bool coachMembership;

  @override
  State<TaqaSubscriptionPage> createState() => _TaqaSubscriptionPageState();
}

class _TaqaSubscriptionPageState extends State<TaqaSubscriptionPage> {
  final InAppPurchase _store = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  final Map<String, ProductDetails> _products = {};
  final Map<String, GoogleBillingOffering> _googleOfferings = {};
  String? _googleObfuscatedAccountId;
  bool _loading = true;
  bool _storeAvailable = false;
  bool _purchasePending = false;
  bool _restoring = false;
  String? _selectedProductId;
  String? _pendingReplacementProductId;
  String? _pendingChangeAction;
  String? _message;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) =>
          _setMessage('$_storeName could not process the purchase.'),
    );
    _loadProducts();
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

      Set<String> productIds = _catalogPlans
          .map((plan) => plan.productId)
          .toSet();
      if (Platform.isAndroid) {
        final offerings = await BillingApi.googleOfferings();
        _googleObfuscatedAccountId = offerings.obfuscatedAccountId;
        _googleOfferings
          ..clear()
          ..addEntries(
            offerings.products.map((item) => MapEntry(item.productId, item)),
          );
        productIds = productIds.intersection(_googleOfferings.keys.toSet());
      }
      final response = await _store.queryProductDetails(productIds);
      if (!mounted) return;
      setState(() {
        _storeAvailable = true;
        _products
          ..clear()
          ..addEntries(_selectStoreProducts(response.productDetails).entries);
        _selectedProductId = _products.containsKey(_selectedProductId)
            ? _selectedProductId
            : _products.keys.firstOrNull;
        _message = response.error?.message;
        if (_products.isEmpty && response.notFoundIDs.isNotEmpty) {
          _message =
              'Subscriptions are not available from $_storeName yet. Please try again soon.';
        }
        _loading = false;
      });
    } catch (_) {
      _setStoreUnavailable();
    }
  }

  void _setStoreUnavailable() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _storeAvailable = false;
      _message = '$_storeName is unavailable. Please try again later.';
    });
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  void _resetPurchaseProgress() {
    if (!mounted) return;
    setState(() {
      _purchasePending = false;
      _restoring = false;
      _pendingReplacementProductId = null;
      _pendingChangeAction = null;
    });
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_catalogPlans
          .map((plan) => plan.productId)
          .contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _purchasePending = true);
        continue;
      }

      var completedMandatorySubscription = false;
      BillingVerificationResult? billingVerification;
      if (purchase.status == PurchaseStatus.error) {
        _setMessage(
          purchase.error?.message ?? 'The purchase could not be completed.',
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (Platform.isAndroid) {
          try {
            billingVerification = await BillingApi.verifyGooglePurchase(
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
              purchaseId: purchase.purchaseID,
              replacementProductId: _pendingReplacementProductId,
            );
            if (!billingVerification.active) {
              _setMessage('This subscription is not currently active.');
              if (purchase.pendingCompletePurchase) {
                await _store.completePurchase(purchase);
              }
              _resetPurchaseProgress();
              continue;
            }
            if (widget.coachMembership && !billingVerification.coachActive) {
              _setMessage('This purchase does not include coach access.');
              _resetPurchaseProgress();
              continue;
            }
            await AccountStorage.setCoachMembershipActive(
              billingVerification.coachActive,
            );
          } on BillingApiException catch (error) {
            _setMessage(
              'Google Play received the purchase, but Taqa could not verify it yet. '
              '${error.message} Use Restore Purchases to retry.',
            );
            _resetPurchaseProgress();
            continue;
          } catch (_) {
            _setMessage(
              'Google Play received the purchase, but Taqa could not verify it yet. '
              'Use Restore Purchases to retry.',
            );
            _resetPurchaseProgress();
            continue;
          }
        }
        _setMessage(
          billingVerification?.changePending == true
              ? 'Your change is scheduled for the next renewal date.'
              : purchase.status == PurchaseStatus.restored
              ? 'Your purchases have been restored.'
              : _pendingChangeAction == 'upgrade_to_coach'
              ? 'Your Taqa Coach membership is active.'
              : 'Your subscription is active.',
        );
        completedMandatorySubscription = widget.mandatory;
      }

      if (completedMandatorySubscription && mounted) {
        await AccountStorage.setSubscriptionRequired(false);
        if (widget.coachMembership) {
          await AccountStorage.setCoachMembershipActive(true);
        }
        if (!mounted) return;
        if (purchase.pendingCompletePurchase) {
          unawaited(_completePurchaseInBackground(purchase));
        }
        Navigator.of(context).pop(true);
        return;
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (mounted) {
        setState(() {
          _purchasePending = false;
          _restoring = false;
          _pendingReplacementProductId = null;
          _pendingChangeAction = null;
        });
      }
    }
  }

  Future<void> _completePurchaseInBackground(PurchaseDetails purchase) async {
    try {
      await _store.completePurchase(purchase);
    } catch (_) {
      // StoreKit will provide the unfinished transaction again on the next
      // launch, where it can be completed without blocking access.
    }
  }

  Future<void> _subscribe() async {
    final productId = _selectedProductId;
    final product = productId == null ? null : _products[productId];
    if (product == null || _purchasePending) return;

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
        change = await BillingApi.prepareGoogleSubscriptionChange(
          targetProductId: product.id,
        );
        if (change.isAlreadySubscribed) {
          _setMessage('This is already your active subscription.');
          return;
        }
        if (!change.isInitialPurchase) {
          changeParam = await _googleChangeSubscriptionParam(change);
        }
      } on BillingApiException catch (error) {
        _setMessage(error.message);
        return;
      } catch (_) {
        _setMessage(
          'Your current Google Play subscription could not be checked.',
        );
        return;
      }
    }
    if (!mounted) return;

    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: change?.action == 'upgrade_to_coach'
          ? 'Confirm coach upgrade'
          : change?.action == 'downgrade_to_standard'
          ? 'Confirm plan change'
          : 'Confirm subscription',
      message: _confirmationMessage(product, change),
      cancelLabel: 'Cancel',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _purchasePending = true;
      _pendingReplacementProductId = change?.isInitialPurchase == false
          ? product.id
          : null;
      _pendingChangeAction = change?.action;
      _message = null;
    });
    try {
      final purchaseParam = Platform.isAndroid
          ? GooglePlayPurchaseParam(
              productDetails: product,
              applicationUserName: _googleObfuscatedAccountId,
              offerToken: product is GooglePlayProductDetails
                  ? product.offerToken
                  : null,
              changeSubscriptionParam: changeParam,
            )
          : PurchaseParam(productDetails: product);
      final started = await _store.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started && mounted) {
        setState(() {
          _purchasePending = false;
          _message = '$_storeName could not start the purchase.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
        _message = 'The purchase could not be started. Please try again.';
      });
    }
  }

  Future<ChangeSubscriptionParam> _googleChangeSubscriptionParam(
    GoogleSubscriptionChange change,
  ) async {
    final currentProductId = change.currentProductId;
    if (currentProductId == null) {
      throw const BillingApiException(
        'The current Google Play subscription is missing.',
      );
    }
    final addition = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) {
      throw BillingApiException(
        response.error?.message ??
            'The current Google Play subscription could not be loaded.',
      );
    }
    final oldPurchase = response.pastPurchases
        .where((purchase) => purchase.productID == currentProductId)
        .firstOrNull;
    if (oldPurchase == null) {
      throw const BillingApiException(
        'Open Google Play with the account that owns the current subscription, then try again.',
      );
    }
    final replacementMode = switch (change.replacementMode) {
      'CHARGE_PRORATED_PRICE' => ReplacementMode.chargeProratedPrice,
      'DEFERRED' => ReplacementMode.deferred,
      _ => throw const BillingApiException(
        'This subscription change is not supported.',
      ),
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
      return 'Upgrade to Taqa Coach now. Google Play will apply credit from your current plan and show the prorated charge before you confirm.';
    }
    if (change?.action == 'downgrade_to_standard') {
      return 'Keep Taqa Coach until the current paid period ends, then switch to the normal ${_displayPrice(product)} plan. Google Play will show the effective date before you confirm.';
    }
    return 'Subscribe for ${_displayPrice(product)} after any displayed free trial. '
        'Your $_accountName will be charged when you confirm in $_storeName.';
  }

  bool _isStudentProduct(String productId) {
    return productId == TaqaSubscriptionCatalog.studentMonthly.productId ||
        productId == TaqaSubscriptionCatalog.studentAnnual.productId;
  }

  List<TaqaSubscriptionPlan> get _catalogPlans =>
      widget.plans ?? TaqaSubscriptionCatalog.plans;

  String get _storeName => Platform.isAndroid ? 'Google Play' : 'the App Store';
  String get _accountName => Platform.isAndroid ? 'Google Account' : 'Apple ID';

  String _displayPrice(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final index = product.subscriptionIndex;
      final phases = index == null
          ? null
          : product
                .productDetails
                .subscriptionOfferDetails?[index]
                .pricingPhases;
      if (phases != null && phases.isNotEmpty) {
        return phases.last.formattedPrice;
      }
    }
    return product.price;
  }

  Map<String, ProductDetails> _selectStoreProducts(
    List<ProductDetails> products,
  ) {
    final selected = <String, ProductDetails>{};
    for (final product in products) {
      if (!Platform.isAndroid || product is! GooglePlayProductDetails) {
        selected[product.id] = product;
        continue;
      }
      final offering = _googleOfferings[product.id];
      final index = product.subscriptionIndex;
      final details = index == null
          ? null
          : product.productDetails.subscriptionOfferDetails?[index];
      final basePlanMatches =
          offering?.basePlanId == null ||
          details?.basePlanId == offering!.basePlanId;
      final offerMatches =
          offering?.offerTag == null ||
          details?.offerTags.contains(offering!.offerTag) == true;
      if (basePlanMatches && offerMatches) {
        selected[product.id] = product;
      } else if (!selected.containsKey(product.id) && basePlanMatches) {
        selected[product.id] = product;
      }
    }
    return selected;
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _message = null;
    });
    try {
      await _store.restorePurchases();
      if (mounted) {
        setState(() {
          _restoring = false;
          _message = 'Your $_storeName purchases have been checked.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _message = 'Purchases could not be restored. Please try again.';
      });
    }
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
        .where((plan) => _products.containsKey(plan.productId))
        .toList(growable: false);
    final canSubscribe =
        selectedProduct != null &&
        _storeAvailable &&
        !_loading &&
        !_purchasePending;
    final canChoosePlan = !_loading && availablePlans.isNotEmpty;

    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        backgroundColor: TaqaUiColors.lightGray,
        appBar: TaqaPageAppBar(
          title: 'Subscriptions',
          showBackButton: !widget.mandatory,
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
          child: ListView(
            padding: TaqaUiScale.insetsLTRB(16, 20, 16, 28),
            children: [
              Text(
                widget.coachMembership
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
                widget.coachMembership
                    ? 'Start your membership to access your coach tools.'
                    : widget.mandatory
                    ? 'Your plan is ready. Subscribe or restore a purchase to unlock it.'
                    : 'One membership for your full Taqa Subscription experience.',
                style: _bodyStyle,
              ),
              SizedBox(height: TaqaUiScale.h(16)),
              _PremiumOverviewCard(
                selectedPrice: selectedProduct == null
                    ? null
                    : _displayPrice(selectedProduct),
                coachMembership: widget.coachMembership,
                onChoosePlan: canChoosePlan
                    ? () => _showPlanPicker(availablePlans)
                    : null,
              ),
              SizedBox(height: TaqaUiScale.h(16)),
              if (_message != null) ...[
                _MessageCard(message: _message!),
                SizedBox(height: TaqaUiScale.h(12)),
              ],
              TaqaFilledButton(
                label: selectedProduct == null
                    ? 'Choose a plan'
                    : 'Subscribe for ${_displayPrice(selectedProduct)}',
                loading: _purchasePending,
                onTap: canSubscribe ? _subscribe : null,
              ),
              SizedBox(height: TaqaUiScale.h(6)),
              TextButton(
                onPressed: _storeAvailable && !_restoring
                    ? _restorePurchases
                    : null,
                child: _restoring
                    ? SizedBox(
                        width: TaqaUiScale.w(18),
                        height: TaqaUiScale.h(18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TaqaUiColors.charcoal,
                        ),
                      )
                    : Text('Restore Purchases', style: _linkStyle),
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              Text(
                'Payment will be charged to your $_accountName when you confirm. '
                'Your subscription automatically renews unless you cancel at '
                'least 24 hours before the end of the current period. You can '
                'manage or cancel it in your $_storeName account settings.',
                style: _bodyStyle,
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              _LegalLinks(onOpen: _openLegalLink),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(TaqaSubscriptionPlan plan) {
    final product = _products[plan.productId];
    return TaqaSubscriptionPlanCard(
      title: plan.title,
      period: plan.periodLabel,
      price: product == null ? '' : _displayPrice(product),
      description: _planDescription(plan),
      student:
          plan == TaqaSubscriptionCatalog.studentMonthly ||
          plan == TaqaSubscriptionCatalog.studentAnnual,
      selected: plan.productId == _selectedProductId,
      onTap: product == null
          ? null
          : () => setState(() {
              _selectedProductId = plan.productId;
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
            _selectedProductId = plan.productId;
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
    required this.selectedPrice,
    required this.coachMembership,
    required this.onChoosePlan,
  });

  final String? selectedPrice;
  final bool coachMembership;
  final VoidCallback? onChoosePlan;

  @override
  Widget build(BuildContext context) {
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(13),
          fontWeight: FontWeight.w400,
          height: 18 / 13,
          color: TaqaUiColors.charcoal,
        ),
      ),
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
