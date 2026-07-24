import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/email_verification_page.dart';
import '../../services/purchases/taqa_subscription_catalog.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_filled_button.dart';
import '../components/taqa_page_app_bar.dart';
import '../components/taqa_subscription_plan_card.dart';
import '../components/taqa_value_dialog.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Taqa Fitness subscriptions purchased through the App Store / StoreKit.
class TaqaSubscriptionPage extends StatefulWidget {
  const TaqaSubscriptionPage({super.key});

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
  String? _selectedProductId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) =>
          _setMessage('The App Store could not process the purchase.'),
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

      final response = await _store.queryProductDetails(
        TaqaSubscriptionCatalog.plans.map((plan) => plan.productId).toSet(),
      );
      if (!mounted) return;
      setState(() {
        _storeAvailable = true;
        _products
          ..clear()
          ..addEntries(
            response.productDetails.map(
              (product) => MapEntry(product.id, product),
            ),
          );
        _selectedProductId = _products.containsKey(_selectedProductId)
            ? _selectedProductId
            : _products.keys.firstOrNull;
        _message = response.error?.message;
        if (_products.isEmpty && response.notFoundIDs.isNotEmpty) {
          _message =
              'Subscriptions are not available from the App Store yet. Please try again soon.';
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
      _message = 'The App Store is unavailable. Please try again later.';
    });
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!TaqaSubscriptionCatalog.plans
          .map((plan) => plan.productId)
          .contains(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _purchasePending = true);
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        _setMessage(
          purchase.error?.message ?? 'The purchase could not be completed.',
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _setMessage(
          purchase.status == PurchaseStatus.restored
              ? 'Your purchases have been restored.'
              : 'Your subscription is active.',
        );
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (mounted) {
        setState(() {
          _purchasePending = false;
          _restoring = false;
        });
      }
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

    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: 'Confirm subscription',
      message:
          'Subscribe for ${product.price}. Your Apple ID will be charged when you confirm in the App Store.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Continue',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _purchasePending = true;
      _message = null;
    });
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started && mounted) {
        setState(() {
          _purchasePending = false;
          _message = 'The App Store could not start the purchase.';
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

  bool _isStudentProduct(String productId) {
    return productId == TaqaSubscriptionCatalog.studentMonthly.productId ||
        productId == TaqaSubscriptionCatalog.studentAnnual.productId;
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
          _message = 'Your App Store purchases have been checked.';
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

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProductId == null
        ? null
        : _products[_selectedProductId];
    final availablePlans = TaqaSubscriptionCatalog.plans
        .where((plan) => _products.containsKey(plan.productId))
        .toList(growable: false);
    final canSubscribe =
        selectedProduct != null &&
        _storeAvailable &&
        !_loading &&
        !_purchasePending;
    final canChoosePlan = !_loading && availablePlans.isNotEmpty;

    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: const TaqaPageAppBar(title: 'Subscriptions'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 28),
          children: [
            Text(
              'Taqa Fitness Premium',
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
              'One membership for your full Taqa Fitness experience.',
              style: _bodyStyle,
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            _PremiumOverviewCard(
              selectedProduct: selectedProduct,
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
                  : 'Subscribe for ${selectedProduct.price}',
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
              'Payment will be charged to your Apple ID when you confirm. '
              'Your subscription automatically renews unless you cancel at '
              'least 24 hours before the end of the current period. You can '
              'manage or cancel it in your App Store account settings.',
              style: _bodyStyle,
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            _LegalLinks(onOpen: _openLegalLink),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(TaqaSubscriptionPlan plan) {
    final product = _products[plan.productId];
    return TaqaSubscriptionPlanCard(
      title: plan.title,
      period: plan.periodLabel,
      price: product?.price ?? '',
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
    if (annual) return 'Full premium access, billed annually.';
    return 'Full premium access, billed monthly.';
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
    required this.selectedProduct,
    required this.onChoosePlan,
  });

  final ProductDetails? selectedProduct;
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
            'Everything in Taqa Premium',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.white,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(6)),
          Text(
            'One membership, all the tools you need to train with intent.',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              color: TaqaUiColors.white.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(14)),
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
                          'Every plan includes the same Taqa Premium features. Tap a plan to select it.',
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
