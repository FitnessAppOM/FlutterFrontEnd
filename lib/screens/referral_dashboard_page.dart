import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_referral_cards.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';
import '../services/referrals/referral_api.dart';
import '../services/share/taqa_share_service.dart';

class ReferralDashboardPage extends StatefulWidget {
  const ReferralDashboardPage({super.key});

  @override
  State<ReferralDashboardPage> createState() => _ReferralDashboardPageState();
}

class _ReferralDashboardPageState extends State<ReferralDashboardPage> {
  ReferralSummary? _summary;
  bool _loading = true;
  bool _loadFailed = false;
  int? _claimingRewardId;
  bool _sharing = false;

  bool get _submitting => _claimingRewardId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showPageLoading = true}) async {
    if (showPageLoading && mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final summary = await ReferralApi.mySummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    } finally {
      if (mounted && showPageLoading) setState(() => _loading = false);
    }
  }

  Future<void> _prepareClaim(ReferralReward reward) async {
    if (_submitting) return;
    setState(() => _claimingRewardId = reward.id);
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
      if (completed == true) await _load(showPageLoading: false);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        _t('referral_dashboard_claim_failed'),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _claimingRewardId = null);
    }
  }

  String _t(String key, [Map<String, Object> values = const {}]) {
    var text = AppLocalizations.of(context).translate(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }

  String _rewardLabel(ReferralReward reward) {
    if (reward.type.startsWith('ordinary_')) {
      return _t('referral_dashboard_reward_free_month');
    }
    if (reward.type.contains('yearly')) {
      return _t('referral_dashboard_reward_coach_yearly');
    }
    return _t('referral_dashboard_reward_coach_monthly');
  }

  String _rewardStatus(ReferralReward reward) {
    return switch (reward.status.toLowerCase()) {
      'qualified' when reward.isClaimable => _t(
        'referral_dashboard_status_claimable',
      ),
      'qualified' => _t('referral_dashboard_status_qualified'),
      'claiming' => _t('referral_dashboard_status_claiming'),
      'applied' => _t('referral_dashboard_status_applied'),
      'voided' => _t('referral_dashboard_status_voided'),
      _ => _t('referral_dashboard_status_unavailable'),
    };
  }

  TaqaReferralRewardTone _rewardTone(ReferralReward reward) {
    if (reward.status == 'applied') return TaqaReferralRewardTone.completed;
    if (reward.isClaimable) return TaqaReferralRewardTone.available;
    return TaqaReferralRewardTone.unavailable;
  }

  String _progressStatus(CoachReferralProgress progress) {
    final count = progress.qualifiedCount;
    if (count >= progress.freeThreshold) {
      return _t('referral_dashboard_progress_free_unlocked');
    }
    if (count >= progress.discountThreshold) {
      return _t('referral_dashboard_progress_half_unlocked');
    }
    return _t('referral_dashboard_progress_more_for_half', {
      'count': progress.discountThreshold - count,
    });
  }

  void _copyCode(ReferralSummary summary) {
    Clipboard.setData(ClipboardData(text: summary.identity.code));
    AppToast.show(
      context,
      _t('settings_referral_code_copied'),
      type: AppToastType.success,
    );
  }

  Future<void> _shareCode(ReferralSummary summary) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final opened = await TaqaShareService.shareText(
        context,
        subject: _t('referral_dashboard_title'),
        text: _t('referral_dashboard_share_text', {
          'url': summary.identity.shareUrl,
          'code': summary.identity.code,
        }),
      );
      if (!opened && mounted) {
        AppToast.show(
          context,
          _t('referral_dashboard_share_failed'),
          type: AppToastType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        _t('referral_dashboard_share_failed'),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.lightGray,
      appBar: TaqaPageAppBar(title: _t('referral_dashboard_title')),
      body: _loading
          ? const Center(child: TaqaLoadingIndicator())
          : _summary == null
          ? _buildUnavailableState()
          : _buildDashboard(_summary!),
    );
  }

  Widget _buildUnavailableState() {
    return SafeArea(
      child: Padding(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TaqaEmptyCard(
              title: _t('referral_dashboard_load_error'),
              subtitle: _t('referral_dashboard_load_error_sub'),
              icon: Icons.wifi_off_rounded,
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaFilledButton(
              label: _t('referral_dashboard_retry'),
              onTap: _loading ? null : _load,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(ReferralSummary summary) {
    final coachRewards = summary.rewards.any(
      (reward) => reward.type.startsWith('coach_'),
    );

    return TaqaRefreshIndicator(
      onRefresh: () => _load(showPageLoading: false),
      showCooldownToast: false,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: TaqaUiScale.insetsLTRB(16, 18, 16, 30),
        children: [
          if (_loadFailed) ...[
            TaqaReferralNoticeCard(
              message: _t('referral_dashboard_refresh_error'),
              actionLabel: _t('referral_dashboard_retry'),
              onAction: () => _load(showPageLoading: false),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
          ],
          TaqaReferralHeroCard(
            title: _t('referral_dashboard_hero_title'),
            description: _t('settings_referral_code_explanation'),
            codeLabel: _t('referral_dashboard_your_code'),
            code: summary.identity.code,
            copyLabel: _t('settings_referral_copy'),
            shareLabel: _t('settings_referral_share'),
            onCopy: () => _copyCode(summary),
            onShare: _sharing ? null : () => _shareCode(summary),
            shareLoading: _sharing,
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          TaqaReferralStatsCard(
            qualifiedLabel: _t('referral_dashboard_qualified'),
            qualifiedValue: summary.qualifiedReferralCount.toString(),
            claimableLabel: _t('referral_dashboard_claimable'),
            claimableValue: summary.claimableCount.toString(),
          ),
          if (coachRewards) ...[
            SizedBox(height: TaqaUiScale.h(22)),
            TaqaReferralSectionTitle(
              title: _t('referral_dashboard_coach_progress'),
            ),
            SizedBox(height: TaqaUiScale.h(9)),
            TaqaReferralProgressCard(
              title: _t('referral_dashboard_monthly_referrals'),
              count: summary.monthlyCoachProgress.qualifiedCount,
              target: summary.monthlyCoachProgress.freeThreshold,
              status: _progressStatus(summary.monthlyCoachProgress),
              milestones: _t('referral_dashboard_monthly_milestones'),
            ),
            SizedBox(height: TaqaUiScale.h(10)),
            TaqaReferralProgressCard(
              title: _t('referral_dashboard_yearly_referrals'),
              count: summary.yearlyCoachProgress.qualifiedCount,
              target: summary.yearlyCoachProgress.freeThreshold,
              status: _progressStatus(summary.yearlyCoachProgress),
              milestones: _t('referral_dashboard_yearly_milestones'),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(22)),
          TaqaReferralSectionTitle(title: _t('referral_dashboard_rewards')),
          SizedBox(height: TaqaUiScale.h(9)),
          if (summary.rewards.isEmpty)
            TaqaEmptyCard(
              title: _t('referral_dashboard_no_rewards'),
              subtitle: _t('referral_dashboard_no_rewards_sub'),
              icon: Icons.card_giftcard_rounded,
              minHeight: TaqaUiScale.h(148),
            )
          else
            ...summary.rewards.map(
              (reward) => Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                child: TaqaReferralRewardCard(
                  title: _rewardLabel(reward),
                  status: _rewardStatus(reward),
                  tone: _rewardTone(reward),
                  claimLabel: _t('referral_dashboard_claim'),
                  onClaim:
                      reward.isClaimable &&
                          (!_submitting || _claimingRewardId == reward.id)
                      ? () => _prepareClaim(reward)
                      : null,
                  loading: _claimingRewardId == reward.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
