import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
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
      appBar: TaqaPageAppBar(
        title: t("fitbit_body_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
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
