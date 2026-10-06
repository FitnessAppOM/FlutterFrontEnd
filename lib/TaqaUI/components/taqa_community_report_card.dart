import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaCommunityReportAction {
  const TaqaCommunityReportAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isEnabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isEnabled;
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
    final t = AppLocalizations.of(context);
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
        border: Border.all(color: colors.border),
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
            '${t.translate('community_report_target')} #$targetId',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(9),
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
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
                color: colors.textSecondary,
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
    final colors = context.taqaColors;
    return Container(
      padding: TaqaUiScale.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized ? colors.accent : colors.surfaceElevated,
        borderRadius: TaqaUiScale.radius(5),
      ),
      child: Text(
        taqaUppercase(label.replaceAll('_', ' ')),
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
          fontSize: TaqaUiScale.sp(8),
          fontWeight: FontWeight.w700,
          color: emphasized ? colors.onAccent : colors.textPrimary,
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
    final colors = context.taqaColors;
    final radius = TaqaUiScale.radius(5);
    return Opacity(
      opacity: action.isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: action.isEnabled ? action.onTap : null,
          borderRadius: radius,
          child: Container(
            height: TaqaUiScale.h(34),
            padding: TaqaUiScale.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: action.isPrimary ? colors.surfaceInverse : colors.surface,
              borderRadius: radius,
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Text(
              taqaUppercase(action.label),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                fontSize: TaqaUiScale.sp(8),
                fontWeight: FontWeight.w700,
                color: action.isPrimary
                    ? colors.textOnInverse
                    : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
