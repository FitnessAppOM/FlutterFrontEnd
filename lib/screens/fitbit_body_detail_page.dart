import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_body_service.dart';

class FitbitBodyDetailPage extends StatelessWidget {
  const FitbitBodyDetailPage({super.key, required this.summary});

  final FitbitBodySummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final weight = summary?.weightKg;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_body_title"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: SingleChildScrollView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: weight == null
                ? TaqaEmptyCard(
                    title: t("fitbit_body_title"),
                    subtitle: t("common_no_records_in_range"),
                    icon: Icons.monitor_weight_outlined,
                  )
                : TaqaLinearMetricCard(
                    title: t("weight"),
                    valueText: "${weight.toStringAsFixed(1)} kg",
                    subtitle: t("fitbit_body_title"),
                    progress: 0,
                    showBar: false,
                    keepBarSpaceWhenHidden: false,
                  ),
          ),
        ),
      ),
    );
  }
}
