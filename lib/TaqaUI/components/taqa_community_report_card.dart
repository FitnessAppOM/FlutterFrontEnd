import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityReportAction {
  const TaqaCommunityReportAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
}

/// Reusable moderation-queue card using the Community TaqaUI language.
class TaqaCommunityReportCard extends StatelessWidget {
  const TaqaCommunityReportCard({
    super.key,
    required this.status,
    required this.targetType,
    required this.reason,
    required this.targetId,
    this.details,
    required this.actions,
  });

  final String status;
  final String targetType;
  final String reason;
  final int targetId;
  final String? details;
  final List<TaqaCommunityReportAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: TaqaUiScale.w(6),
            runSpacing: TaqaUiScale.h(6),
            children: [
              TaqaCommunityReportTag(label: status, emphasized: true),
              TaqaCommunityReportTag(label: targetType),
              TaqaCommunityReportTag(label: reason),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          Text(
            'TARGET #$targetId',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(9),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
            ),
          ),
          if (details != null && details!.trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              details!,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(14),
                height: 1.35,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.74),
              ),
            ),
          ],
          SizedBox(height: TaqaUiScale.h(16)),
          Wrap(
            spacing: TaqaUiScale.w(8),
            runSpacing: TaqaUiScale.h(8),
            children: actions
                .map((action) => _TaqaCommunityReportButton(action: action))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class TaqaCommunityReportTag extends StatelessWidget {
  const TaqaCommunityReportTag({
    super.key,
    required this.label,
    this.emphasized = false,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? TaqaUiColors.accent
            : TaqaUiColors.charcoal.withValues(alpha: 0.06),
        borderRadius: TaqaUiScale.radius(5),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
          fontSize: TaqaUiScale.sp(8),
          fontWeight: FontWeight.w700,
          color: TaqaUiColors.charcoal,
        ),
      ),
    );
  }
}

class _TaqaCommunityReportButton extends StatelessWidget {
  const _TaqaCommunityReportButton({required this.action});

  final TaqaCommunityReportAction action;

  @override
  Widget build(BuildContext context) {
    final radius = TaqaUiScale.radius(5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: radius,
        child: Container(
          height: TaqaUiScale.h(34),
          padding: TaqaUiScale.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: action.isPrimary
                ? TaqaUiColors.charcoal
                : TaqaUiColors.white,
            borderRadius: radius,
            border: Border.all(color: TaqaUiColors.charcoal, width: 0.5),
          ),
          child: Text(
            action.label.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w700,
              color: action.isPrimary
                  ? TaqaUiColors.white
                  : TaqaUiColors.charcoal,
            ),
          ),
        ),
      ),
    );
  }
}
