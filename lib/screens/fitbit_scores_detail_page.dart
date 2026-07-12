import 'package:flutter/material.dart';

import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
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
      appBar: TaqaPageAppBar(
        title: t("fitbit_scores_title"),
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
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
                : Column(
                    children: [
                      TaqaPillarCard(
                        metricKey: 'fitbit_readiness',
                        label: t("fitbit_scores_readiness"),
                        score: readiness?.toDouble(),
                        icon: Icons.flash_on_rounded,
                        color: const Color(0xFFFFD700),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: _fmtScore(readiness),
                      ),
                      SizedBox(height: TaqaUiScale.h(12)),
                      TaqaPillarCard(
                        metricKey: 'stress',
                        label: t("fitbit_scores_stress"),
                        score: stress?.toDouble(),
                        icon: Icons.psychology_rounded,
                        color: const Color(0xFF4CD964),
                        details: const {},
                        detailLabels: const {},
                        valueDisplay: _fmtScore(stress),
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
