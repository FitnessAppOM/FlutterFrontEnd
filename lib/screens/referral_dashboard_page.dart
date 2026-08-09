import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/referrals/referral_api.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';

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
      return r'$5 off the next yearly payment';
    }
    return r'$1 off the next monthly payment';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referrals and rewards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_summary != null) ...[
                    Text(
                      'Your referral code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_summary!.identity.code),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _summary!.identity.code),
                          ),
                          child: const Text('Copy'),
                        ),
                        FilledButton(
                          onPressed: () => Share.share(
                            'Join me on Taqa: ${_summary!.identity.shareUrl}',
                          ),
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    if (!_summary!.hasAttribution) ...[
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Enter a referral code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _submitting ? null : _redeem,
                        child: const Text('Accept referral'),
                      ),
                      const Divider(height: 32),
                    ],
                    Text(
                      'Qualified referrals: ${_summary!.qualifiedReferralCount}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Claimable rewards: ${_summary!.claimableCount}'),
                    const SizedBox(height: 12),
                    if (_summary!.rewards.isEmpty)
                      const Text('No referral rewards yet.')
                    else
                      ..._summary!.rewards.map(
                        (reward) => Card(
                          child: ListTile(
                            title: Text(_rewardLabel(reward)),
                            subtitle: Text('Status: ${reward.status}'),
                            trailing: reward.isClaimable
                                ? FilledButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _prepareClaim(reward),
                                    child: const Text('Claim'),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
