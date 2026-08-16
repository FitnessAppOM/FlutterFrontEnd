import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../localization/app_localizations.dart';

class TrainingDayCompleteSheet extends StatelessWidget {
  const TrainingDayCompleteSheet({super.key, required this.dayLabel});

  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: TaqaUiScale.insetsLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: TaqaUiColors.graphite,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.w(15)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: TaqaUiScale.w(42),
              height: TaqaUiScale.h(4),
              decoration: BoxDecoration(
                color: TaqaUiColors.white.withValues(alpha: 0.25),
                borderRadius: TaqaUiScale.radius(4),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(24)),
            Container(
              width: TaqaUiScale.w(64),
              height: TaqaUiScale.w(64),
              decoration: BoxDecoration(
                color: TaqaUiColors.lime,
                borderRadius: TaqaUiScale.radius(18),
              ),
              child: Icon(
                Icons.check_rounded,
                size: TaqaUiScale.w(38),
                color: TaqaUiColors.charcoal,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(18)),
            Text(
              t.translate('training_day_complete'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(24),
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: TaqaUiColors.white,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Text(
              t
                  .translate('training_day_finished')
                  .replaceAll('{day}', dayLabel),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(14),
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: TaqaUiColors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(24)),
            TaqaFilledButton(
              label: t.translate('training_nice'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
