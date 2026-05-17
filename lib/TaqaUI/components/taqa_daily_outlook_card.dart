import 'package:flutter/material.dart';

import '../../services/daily_outlook/daily_outlook_service.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_layout.dart';
import '../styles/taqa_ui_styles.dart';
import '../taqa_ui_colors.dart';

class DailyOutlookCard extends StatelessWidget {
  const DailyOutlookCard({
    super.key,
    required this.loading,
    required this.generating,
    required this.status,
    required this.onGenerate,
    required this.onOpen,
    required this.title,
    required this.subtitle,
    required this.generateLabel,
    required this.generatedLabel,
    required this.onceDailyLabel,
    required this.viewLabel,
  });

  final bool loading;
  final bool generating;
  final DailyOutlookStatus? status;
  final VoidCallback? onGenerate;
  final VoidCallback? onOpen;
  final String title;
  final String subtitle;
  final String generateLabel;
  final String generatedLabel;
  final String onceDailyLabel;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    final outlook = status?.outlook;
    final generated = status?.generated == true && outlook != null;
    final tagText = generated && outlook.readinessState.trim().isNotEmpty
        ? outlook.readinessState.trim()
        : 'DAILY OUTLOOK';
    final headlineText = generated && outlook.headline.trim().isNotEmpty
        ? outlook.headline.trim()
        : generateLabel;
    final summaryText = generated && outlook.summary.trim().isNotEmpty
        ? outlook.summary.trim()
        : subtitle;
    final busy = loading || generating;
    final actionText = generating
        ? "$generateLabel..."
        : (generated ? viewLabel : generateLabel);
    final onTap = busy ? null : (generated ? onOpen : onGenerate);

    return Container(
      decoration: const BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiStyles.cardRadius,
      ),
      child: Padding(
        padding: TaqaUiLayout.dailyOutlookContentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tagText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                      fontSize: 8,
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.charcoal,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              headlineText,
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TaqaUiColors.charcoal,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summaryText,
              style: const TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: 10,
                fontWeight: FontWeight.w300,
                color: TaqaUiColors.charcoal,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 15),
            _DailyOutlookActionButton(label: actionText, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _DailyOutlookActionButton extends StatelessWidget {
  const _DailyOutlookActionButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: TaqaUiStyles.actionButtonHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: onTap == null
                  ? TaqaUiColors.lime.withValues(alpha: 0.6)
                  : TaqaUiColors.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: TaqaUiColors.charcoal,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
