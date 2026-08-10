import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/referrals/referral_api.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';

class ReferralDashboardPage extends StatefulWidget {
  const ReferralDashboardPage({super.key});

  @override
  State<ReferralDashboardPage> createState() => _ReferralDashboardPageState();
}

class _ReferralDashboardPageState extends State<ReferralDashboardPage> {
  final _codeController = TextEditingController();
  ReferralSummary? _summary;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString('pending_referral_code');
      final summary = await ReferralApi.mySummary();
      if (!mounted) return;
      _codeController.text = pending ?? '';
      setState(() => _summary = summary);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReferralApi.redeem(code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code accepted.')));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _prepareClaim(ReferralReward reward) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final preparation = await ReferralApi.prepareClaim(
        rewardId: reward.id,
        platform: Platform.isIOS ? 'apple' : 'google',
      );
      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TaqaSubscriptionPage(
            coachMembership: preparation.productId.contains('coach'),
            allowPlanTypeSwitch: false,
            allowBackNavigation: true,
            referralClaimToken: preparation.claimToken,
            googleReferralOfferTag: preparation.offerId,
            referralProductId: preparation.productId,
            appleOfferAuthorization: preparation.appleOfferAuthorization,
          ),
        ),
      );
      if (completed == true) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _rewardLabel(ReferralReward reward) {
    if (reward.type.startsWith('ordinary_')) {
      return 'One free month';
    }
    if (reward.type.contains('yearly')) {
      return 'Coach yearly referral reward';
    }
    return 'Coach monthly referral reward';
  }

  TextStyle _textStyle({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = TaqaUiColors.unnamedColor1c1d17,
  }) {
    return TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(size),
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _compactAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Expanded(
      child: Material(
        color: filled ? TaqaUiColors.lime : TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: TaqaUiScale.radius(8),
          child: Container(
            height: TaqaUiScale.h(44),
            decoration: BoxDecoration(
              borderRadius: TaqaUiScale.radius(8),
              border: Border.all(
                color: TaqaUiColors.unnamedColor1c1d17,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: TaqaUiScale.w(17)),
                SizedBox(width: TaqaUiScale.w(7)),
                Text(label.toUpperCase(), style: _textStyle(size: 11, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: const TaqaPageAppBar(title: 'Referrals and rewards'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TaqaUiColors.charcoal),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: TaqaUiScale.insetsLTRB(16, 20, 16, 28),
                children: [
                  if (_error != null)
                    Container(
                      margin: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                      padding: TaqaUiScale.insetsLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: TaqaUiColors.recordRed.withValues(alpha: 0.10),
                        borderRadius: TaqaUiScale.radius(10),
                        border: Border.all(
                          color: TaqaUiColors.recordRed.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: _textStyle(color: TaqaUiColors.recordRed),
                      ),
                    ),
                  if (_summary != null) ...[
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR REFERRAL CODE', style: _textStyle(size: 11, weight: FontWeight.w700)),
                          SizedBox(height: TaqaUiScale.h(6)),
                          Text(
                            'Share this code with new Taqa members.',
                            style: _textStyle(
                              size: 12,
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.62),
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(14)),
                          Container(
                            width: double.infinity,
                            padding: TaqaUiScale.insetsLTRB(14, 13, 14, 13),
                            decoration: BoxDecoration(
                              color: TaqaUiColors.unnamedColorE3e3e3.withValues(alpha: 0.55),
                              borderRadius: TaqaUiScale.radius(10),
                              border: Border.all(
                                color: TaqaUiColors.unnamedColor1c1d17,
                                width: 1.2,
                              ),
                            ),
                            child: SelectableText(
                              _summary!.identity.code,
                              textAlign: TextAlign.center,
                              style: _textStyle(size: 22, weight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(12)),
                          Row(
                            children: [
                              _compactAction(
                                label: 'Copy',
                                icon: Icons.copy_rounded,
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _summary!.identity.code),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Referral code copied.')),
                                  );
                                },
                              ),
                              SizedBox(width: TaqaUiScale.w(10)),
                              _compactAction(
                                label: 'Share',
                                icon: Icons.ios_share_rounded,
                                filled: true,
                                onTap: () => Share.share(
                                  'Join me on Taqa: ${_summary!.identity.shareUrl}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(14)),
                    if (!_summary!.hasAttribution) ...[
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HAVE A REFERRAL CODE?', style: _textStyle(size: 11, weight: FontWeight.w700)),
                            SizedBox(height: TaqaUiScale.h(6)),
                            Text(
                              'Enter it before your first successful paid charge.',
                              style: _textStyle(
                                size: 12,
                                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.62),
                              ),
                            ),
                            SizedBox(height: TaqaUiScale.h(14)),
                            TextField(
                              controller: _codeController,
                              enabled: !_submitting,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: _textStyle(size: 16, weight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: _textStyle(
                                  size: 13,
                                  color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.42),
                                ),
                                prefixIcon: const Icon(
                                  Icons.confirmation_number_outlined,
                                  color: TaqaUiColors.charcoal,
                                ),
                                filled: true,
                                fillColor: TaqaUiColors.white,
                                contentPadding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: TaqaUiScale.radius(10),
                                  borderSide: const BorderSide(
                                    color: TaqaUiColors.charcoal,
                                    width: 1.4,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: TaqaUiScale.radius(10),
                                  borderSide: const BorderSide(
                                    color: TaqaUiColors.lime,
                                    width: 2.2,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: TaqaUiScale.radius(10),
                                  borderSide: BorderSide(
                                    color: TaqaUiColors.charcoal.withValues(alpha: 0.30),
                                  ),
                                ),
                              ),
                              onSubmitted: (_) {
                                if (!_submitting) _redeem();
                              },
                            ),
                            SizedBox(height: TaqaUiScale.h(12)),
                            TaqaFilledButton(
                              label: 'Accept referral',
                              loading: _submitting,
                              onTap: _submitting ? null : _redeem,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(14)),
                    ],
                    _card(
                      child: Row(
                        children: [
                          Expanded(
                            child: _stat(
                              'QUALIFIED',
                              _summary!.qualifiedReferralCount.toString(),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: TaqaUiScale.h(42),
                            color: TaqaUiColors.charcoal.withValues(alpha: 0.14),
                          ),
                          Expanded(
                            child: _stat(
                              'CLAIMABLE',
                              _summary!.claimableCount.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(18)),
                    Text('REWARDS', style: _textStyle(size: 12, weight: FontWeight.w700)),
                    SizedBox(height: TaqaUiScale.h(10)),
                    if (_summary!.rewards.isEmpty)
                      _card(
                        child: Text(
                          'No referral rewards yet.',
                          style: _textStyle(
                            color: TaqaUiColors.charcoal.withValues(alpha: 0.62),
                          ),
                        ),
                      )
                    else
                      ..._summary!.rewards.map(
                        (reward) => Padding(
                          padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                          child: _card(
                            child: Row(
                              children: [
                                Container(
                                  width: TaqaUiScale.w(40),
                                  height: TaqaUiScale.h(40),
                                  decoration: const BoxDecoration(
                                    color: TaqaUiColors.lime,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.card_giftcard_rounded),
                                ),
                                SizedBox(width: TaqaUiScale.w(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_rewardLabel(reward), style: _textStyle(weight: FontWeight.w700)),
                                      SizedBox(height: TaqaUiScale.h(2)),
                                      Text(
                                        'Status: ${reward.status}',
                                        style: _textStyle(
                                          size: 11,
                                          color: TaqaUiColors.charcoal.withValues(alpha: 0.58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (reward.isClaimable)
                                  TextButton(
                                    onPressed: _submitting ? null : () => _prepareClaim(reward),
                                    style: TextButton.styleFrom(
                                      foregroundColor: TaqaUiColors.charcoal,
                                      backgroundColor: TaqaUiColors.lime,
                                      shape: RoundedRectangleBorder(borderRadius: TaqaUiScale.radius(7)),
                                    ),
                                    child: Text('CLAIM', style: _textStyle(size: 10, weight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: _textStyle(size: 22, weight: FontWeight.w700)),
        SizedBox(height: TaqaUiScale.h(2)),
        Text(
          label,
          style: _textStyle(
            size: 10,
            weight: FontWeight.w600,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.58),
          ),
        ),
      ],
    );
  }
}
