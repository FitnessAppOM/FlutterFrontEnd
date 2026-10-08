import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_loading_indicator.dart';
import 'taqa_pressable.dart';

class TaqaReferralSectionTitle extends StatelessWidget {
  const TaqaReferralSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Text(
      taqaUppercase(title),
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
        fontSize: TaqaUiScale.sp(9),
        fontWeight: FontWeight.w400,
        height: 12 / 9,
        letterSpacing: 0.2,
        color: colors.textSecondary,
      ),
    );
  }
}

class TaqaReferralHeroCard extends StatelessWidget {
  const TaqaReferralHeroCard({
    super.key,
    required this.title,
    required this.description,
    required this.codeLabel,
    required this.code,
    required this.copyLabel,
    required this.shareLabel,
    required this.onCopy,
    required this.onShare,
    this.shareLoading = false,
  });

  final String title;
  final String description;
  final String codeLabel;
  final String code;
  final String copyLabel;
  final String shareLabel;
  final VoidCallback onCopy;
  final VoidCallback? onShare;
  final bool shareLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: TaqaUiScale.w(42),
                height: TaqaUiScale.h(42),
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: TaqaUiScale.w(20),
                  color: colors.onAccent,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(18),
                        fontWeight: FontWeight.w700,
                        height: 22 / 18,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(4)),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(11),
                        fontWeight: FontWeight.w400,
                        height: 15 / 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(18)),
          Text(
            taqaUppercase(codeLabel),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(7)),
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: TaqaUiScale.insetsLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: TaqaUiScale.radius(8),
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(24),
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: colors.accent,
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Row(
            children: [
              Expanded(
                child: _TaqaReferralActionButton(
                  label: copyLabel,
                  icon: Icons.copy_rounded,
                  onTap: onCopy,
                  backgroundColor: colors.surfaceElevated,
                ),
              ),
              SizedBox(width: TaqaUiScale.w(10)),
              Expanded(
                child: _TaqaReferralActionButton(
                  label: shareLabel,
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                  backgroundColor: colors.accent,
                  loading: shareLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TaqaReferralStatsCard extends StatelessWidget {
  const TaqaReferralStatsCard({
    super.key,
    required this.qualifiedLabel,
    required this.qualifiedValue,
    required this.claimableLabel,
    required this.claimableValue,
  });

  final String qualifiedLabel;
  final String qualifiedValue;
  final String claimableLabel;
  final String claimableValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TaqaReferralStat(
              icon: Icons.people_alt_outlined,
              label: qualifiedLabel,
              value: qualifiedValue,
            ),
          ),
          Container(
            width: TaqaUiScale.w(1),
            height: TaqaUiScale.h(48),
            color: colors.divider,
          ),
          Expanded(
            child: _TaqaReferralStat(
              icon: Icons.redeem_outlined,
              label: claimableLabel,
              value: claimableValue,
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaReferralProgressCard extends StatelessWidget {
  const TaqaReferralProgressCard({
    super.key,
    required this.title,
    required this.count,
    required this.target,
    required this.status,
    required this.milestones,
  });

  final String title;
  final int count;
  final int target;
  final String status;
  final String milestones;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final progress = target <= 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: _TaqaReferralText.title(context)),
              ),
              Container(
                padding: TaqaUiScale.insetsLTRB(9, 4, 9, 4),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: TaqaUiScale.radius(20),
                ),
                child: Text(
                  '$count / $target',
                  style: _TaqaReferralText.tag(
                    context,
                  ).copyWith(color: colors.onAccent),
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(13)),
          ClipRRect(
            borderRadius: TaqaUiScale.radius(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: TaqaUiScale.h(8),
              backgroundColor: colors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(10)),
          Text(status, style: _TaqaReferralText.bodyStrong(context)),
          SizedBox(height: TaqaUiScale.h(3)),
          Text(milestones, style: _TaqaReferralText.caption(context)),
        ],
      ),
    );
  }
}

enum TaqaReferralRewardTone { available, completed, unavailable }

class TaqaReferralRewardCard extends StatelessWidget {
  const TaqaReferralRewardCard({
    super.key,
    required this.title,
    required this.status,
    required this.tone,
    required this.claimLabel,
    required this.onClaim,
    required this.loading,
  });

  final String title;
  final String status;
  final TaqaReferralRewardTone tone;
  final String claimLabel;
  final VoidCallback? onClaim;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    final statusBackground = switch (tone) {
      TaqaReferralRewardTone.available => colors.accent,
      TaqaReferralRewardTone.completed => colors.surfaceElevated,
      TaqaReferralRewardTone.unavailable => colors.surfaceElevated,
    };
    final statusColor = tone == TaqaReferralRewardTone.completed
        ? colors.textPrimary
        : tone == TaqaReferralRewardTone.available
        ? colors.onAccent
        : colors.textSecondary;

    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: TaqaUiScale.w(42),
            height: TaqaUiScale.h(42),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              size: TaqaUiScale.w(19),
              color: colors.accent,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _TaqaReferralText.title(context)),
                SizedBox(height: TaqaUiScale.h(5)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: TaqaUiScale.insetsLTRB(8, 3, 8, 3),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: TaqaUiScale.radius(20),
                    ),
                    child: Text(
                      taqaUppercase(status),
                      style: _TaqaReferralText.tag(
                        context,
                      ).copyWith(color: statusColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onClaim != null) ...[
            SizedBox(width: TaqaUiScale.w(10)),
            TaqaPressable(
              onTap: loading ? null : onClaim,
              semanticLabel: claimLabel,
              child: Container(
                constraints: BoxConstraints(minWidth: TaqaUiScale.w(70)),
                height: TaqaUiScale.h(38),
                padding: TaqaUiScale.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: TaqaUiScale.radius(5),
                ),
                child: loading
                    ? const TaqaLoadingIndicator(size: 14)
                    : Text(
                        taqaUppercase(claimLabel),
                        style: _TaqaReferralText.button(
                          context,
                        ).copyWith(color: colors.onAccent),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TaqaReferralNoticeCard extends StatelessWidget {
  const TaqaReferralNoticeCard({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.danger.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: TaqaUiScale.w(26),
            height: TaqaUiScale.h(26),
            decoration: BoxDecoration(
              color: colors.danger,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.priority_high_rounded,
              size: TaqaUiScale.w(15),
              color: colors.onDanger,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(10)),
          Expanded(
            child: Text(message, style: _TaqaReferralText.body(context)),
          ),
          SizedBox(width: TaqaUiScale.w(8)),
          TaqaPressable(
            onTap: onAction,
            semanticLabel: actionLabel,
            child: Padding(
              padding: TaqaUiScale.symmetric(horizontal: 5, vertical: 6),
              child: Text(
                taqaUppercase(actionLabel),
                style: _TaqaReferralText.button(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaqaReferralActionButton extends StatelessWidget {
  const _TaqaReferralActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return TaqaPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: TaqaUiScale.h(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: TaqaUiScale.radius(5),
        ),
        child: loading
            ? const TaqaLoadingIndicator(size: 16)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: TaqaUiScale.w(16),
                    color: colors.textPrimary,
                  ),
                  SizedBox(width: TaqaUiScale.w(7)),
                  Flexible(
                    child: Text(
                      taqaUppercase(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _TaqaReferralText.button(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TaqaReferralStat extends StatelessWidget {
  const _TaqaReferralStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: TaqaUiScale.w(20), color: colors.textPrimary),
        SizedBox(width: TaqaUiScale.w(9)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: _TaqaReferralText.value(context)),
            SizedBox(height: TaqaUiScale.h(2)),
            Text(
              taqaUppercase(label),
              style: _TaqaReferralText.caption(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaqaReferralText {
  const _TaqaReferralText._();

  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(14),
    fontWeight: FontWeight.w700,
    height: 18 / 14,
    color: context.taqaColors.textPrimary,
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(11),
    fontWeight: FontWeight.w400,
    height: 15 / 11,
    color: context.taqaColors.textPrimary,
  );

  static TextStyle bodyStrong(BuildContext context) =>
      body(context).copyWith(fontWeight: FontWeight.w600);

  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(9),
    fontWeight: FontWeight.w400,
    height: 12 / 9,
    color: context.taqaColors.textSecondary,
  );

  static TextStyle tag(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
    fontSize: TaqaUiScale.sp(8),
    fontWeight: FontWeight.w400,
    height: 10 / 8,
    color: context.taqaColors.textPrimary,
  );

  static TextStyle button(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(10),
    fontWeight: FontWeight.w700,
    height: 12 / 10,
    color: context.taqaColors.textPrimary,
  );

  static TextStyle value(BuildContext context) => TextStyle(
    fontFamily: TaqaUiFontFamilies.interTight,
    fontSize: TaqaUiScale.sp(23),
    fontWeight: FontWeight.w700,
    height: 1,
    color: context.taqaColors.textPrimary,
  );
}
