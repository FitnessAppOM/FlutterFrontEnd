import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';
import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../services/purchases/taqa_subscription_catalog.dart';
import 'expert_questionnaire.dart';

/// Locks coach applicants out of the app until an admin decision is made and,
/// once approved, until their coach membership is started.
class CoachApplicationStatusPage extends StatefulWidget {
  const CoachApplicationStatusPage({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<CoachApplicationStatusPage> createState() =>
      _CoachApplicationStatusPageState();
}

class _CoachApplicationStatusPageState
    extends State<CoachApplicationStatusPage> {
  final InAppPurchase _store = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  String _status = 'pending';
  bool _loading = true;
  bool _checkingStoreEntitlement = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialStatus = widget.initialStatus?.trim().toLowerCase();
    if (initialStatus != null && initialStatus.isNotEmpty) {
      _status = initialStatus;
    }
    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
    );
    _refreshStatus();
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }

  Future<void> _restoreCoachMembership() async {
    if (mounted) {
      setState(() => _checkingStoreEntitlement = true);
    }
    try {
      if (await _hasActiveCoachStoreKitEntitlement()) {
        await AccountStorage.setCoachMembershipActive(true);
        await _continueIfCoachMembershipIsActive();
        return;
      }
      await _store.restorePurchases();
    } catch (_) {
      // Checkout still offers a manual restore if StoreKit is unavailable.
    } finally {
      if (mounted) setState(() => _checkingStoreEntitlement = false);
    }
  }

  Future<bool> _hasActiveCoachStoreKitEntitlement() async {
    if (!Platform.isIOS) return false;
    try {
      final transactions = await SK2Transaction.transactions();
      final now = DateTime.now().toUtc();
      return transactions.any((transaction) {
        if (transaction.productId !=
            TaqaSubscriptionCatalog.coachMonthly.productId) {
          return false;
        }
        final expirationRaw = transaction.expirationDate;
        final expiration = expirationRaw == null
            ? null
            : DateTime.tryParse(expirationRaw)?.toUtc();
        return expiration != null && expiration.isAfter(now);
      });
    } catch (_) {
      // StoreKit 1 and older iOS versions fall back to restorePurchases().
      return false;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final coachPurchases = purchases.where(
      (purchase) =>
          purchase.productID ==
              TaqaSubscriptionCatalog.coachMonthly.productId &&
          purchase.status == PurchaseStatus.restored,
    );
    if (coachPurchases.isEmpty) return;

    for (final purchase in coachPurchases) {
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    await AccountStorage.setCoachMembershipActive(true);
    await _continueIfCoachMembershipIsActive();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) throw StateError('Sign in again.');
      final profile = await ProfileApi.fetchProfile(userId);
      final status = (profile['expert_profile_status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      await AccountStorage.setCoachApplicationStatus(
        status.isEmpty ? 'pending' : status,
      );
      if (!mounted) return;
      setState(() {
        _status = status.isEmpty ? 'pending' : status;
        _loading = false;
      });
      if (_status == 'approved') {
        await _restoreCoachMembership();
      }
      await _continueIfCoachMembershipIsActive();
    } catch (_) {
      final cachedStatus = await AccountStorage.getCoachApplicationStatus();
      if (!mounted) return;
      setState(() {
        if (cachedStatus != null) _status = cachedStatus;
        _error = 'We could not check your application yet. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _continueIfCoachMembershipIsActive() async {
    if (_status != 'approved' ||
        !await AccountStorage.isCoachMembershipActive() ||
        !mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
  }

  Future<void> _startMembership() async {
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TaqaSubscriptionPage(
          mandatory: true,
          coachMembership: true,
          plans: [TaqaSubscriptionCatalog.coachMonthly],
        ),
      ),
    );
    if (!mounted || subscribed != true) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
  }

  void _reapply() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ExpertQuestionnairePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'rejected';
    final approved = _status == 'approved';
    final title = approved
        ? 'Your coach application was accepted'
        : rejected
        ? 'Your coach application was not accepted'
        : 'Your coach application is under review';
    final body = approved
        ? 'Start your Taqa Coach membership to unlock your coach tools and the rest of the app.'
        : rejected
        ? 'You can update your information and submit a new application for review.'
        : 'Our team is reviewing your application. You will be able to continue once it has been accepted.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        appBar: const TaqaPageAppBar(
          title: 'Coach application',
          showBackButton: false,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(20, 28, 20, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: TaqaUiScale.w(82),
                  height: TaqaUiScale.w(82),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: approved
                        ? TaqaUiColors.accent
                        : rejected
                        ? TaqaUiColors.recordRed
                        : TaqaUiColors.white,
                  ),
                  child: Icon(
                    approved
                        ? Icons.workspace_premium_rounded
                        : rejected
                        ? Icons.refresh_rounded
                        : Icons.hourglass_top_rounded,
                    size: TaqaUiScale.w(38),
                    color: TaqaUiColors.charcoal,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(24)),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(24),
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.charcoal,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Text(
                  _error ?? body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    height: 1.4,
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.68),
                  ),
                ),
                const Spacer(),
                if (_loading || _checkingStoreEntitlement)
                  const CircularProgressIndicator(color: TaqaUiColors.charcoal)
                else if (approved)
                  TaqaFilledButton(
                    label: 'Continue to payment',
                    onTap: _startMembership,
                  )
                else if (rejected)
                  TaqaFilledButton(label: 'Reapply', onTap: _reapply)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
