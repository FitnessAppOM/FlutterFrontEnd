import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_progress_widget_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../localization/app_localizations.dart';
import '../services/fitbit/fitbit_scores_service.dart';

class FitbitScoresDetailPage extends StatelessWidget {
  const FitbitScoresDetailPage({super.key, required this.summary});

  final FitbitScoresSummary? summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final readiness = summary?.readinessScore;
    final stress = summary?.stressManagementScore;
    final hasData = readiness != null || stress != null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          t("fitbit_scores_title"),
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
            child: !hasData
                ? TaqaEmptyCard(
                    title: t("fitbit_scores_title"),
                    subtitle: t("common_no_records_in_range"),
                    icon: Icons.insights_outlined,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TaqaProgressWidgetCard(
                          title: t("fitbit_scores_readiness"),
                          valueText: _fmtScore(readiness),
                          goalText: t("fitbit_scores_title"),
                          progress: readiness == null ? 0.0 : readiness / 100,
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(12)),
                      Expanded(
                        child: TaqaProgressWidgetCard(
                          title: t("fitbit_scores_stress"),
                          valueText: _fmtScore(stress),
                          goalText: t("fitbit_scores_title"),
                          progress: stress == null ? 0.0 : stress / 100,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _fmtScore(int? value) => value == null ? "—" : "$value%";
}
