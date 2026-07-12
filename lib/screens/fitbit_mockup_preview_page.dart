import 'package:flutter/material.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/fitbit/fitbit_activity_service.dart';
import '../services/fitbit/fitbit_body_service.dart';
import '../services/fitbit/fitbit_scores_service.dart';
import '../services/fitbit/fitbit_vitals_service.dart';
import 'fitbit_body_detail_page.dart';
import 'fitbit_daily_activity_detail_page.dart';
import 'fitbit_heart_detail_page.dart';
import 'fitbit_scores_detail_page.dart';
import 'fitbit_vitals_detail_page.dart';

/// Dev-only screen for eyeballing the Fitbit detail page designs without a
/// connected Fitbit account. Feeds each page hand-picked mock data instead
/// of a live summary. Not linked from any production flow.
class FitbitMockupPreviewPage extends StatelessWidget {
  const FitbitMockupPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: const TaqaPageAppBar(
        title: 'Fitbit Design Preview',
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      ),
      body: SafeArea(
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
          children: [
            _entry(
              context,
              label: 'Scores',
              icon: Icons.insights_outlined,
              builder: (_) => const FitbitScoresDetailPage(
                summary: FitbitScoresSummary(
                  sleepScore: 82,
                  readinessScore: 74,
                  stressManagementScore: 61,
                ),
              ),
            ),
            _entry(
              context,
              label: 'Daily Activity',
              icon: Icons.directions_walk_rounded,
              builder: (_) => FitbitDailyActivityDetailPage(
                date: today,
                summary: const FitbitActivitySummary(
                  steps: 8342,
                  distance: 6.1,
                  calories: 2210,
                  floors: 9,
                  activeMinutes: 47,
                  goalSteps: 10000,
                  goalDistance: 8.0,
                  goalCalories: 2600,
                  goalFloors: 12,
                  goalActiveMinutes: 60,
                ),
              ),
            ),
            _entry(
              context,
              label: 'Heart & Cardio',
              icon: Icons.favorite_rounded,
              builder: (_) => FitbitHeartDetailPage(
                date: today,
                restingHr: 58,
                hrvRmssd: 42.3,
                vo2Max: '48.5',
                zones: const [
                  {'name': 'Fat Burn', 'min': 98, 'max': 136, 'minutes': 62},
                  {'name': 'Cardio', 'min': 136, 'max': 167, 'minutes': 21},
                  {'name': 'Peak', 'min': 167, 'max': 220, 'minutes': 4},
                ],
              ),
            ),
            _entry(
              context,
              label: 'Health Metrics (Vitals)',
              icon: Icons.air_rounded,
              builder: (_) => const FitbitVitalsDetailPage(
                summary: FitbitVitalsSummary(
                  spo2Percent: 97,
                  spo2Min: 93,
                  spo2Max: 99,
                  skinTempC: -0.4,
                  breathingRate: 15.2,
                  ecgSummary: 'Normal Sinus Rhythm',
                  ecgAvgHr: 64,
                ),
              ),
            ),
            _entry(
              context,
              label: 'Body',
              icon: Icons.monitor_weight_rounded,
              builder: (_) => const FitbitBodyDetailPage(
                summary: FitbitBodySummary(weightKg: 76.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required String label,
    required IconData icon,
    required WidgetBuilder builder,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: Material(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
        child: InkWell(
          borderRadius: TaqaUiScale.radius(15),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: builder)),
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Icon(icon, color: TaqaUiColors.charcoal),
                SizedBox(width: TaqaUiScale.w(12)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
