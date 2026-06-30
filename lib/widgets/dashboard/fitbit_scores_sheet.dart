import 'package:flutter/material.dart';

import '../../services/fitbit/fitbit_scores_service.dart';
import '../../theme/app_theme.dart';
import '../../localization/app_localizations.dart';

class FitbitScoresSheet extends StatelessWidget {
  final FitbitScoresSummary? summary;

  const FitbitScoresSheet({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1F27), Color(0xFF13151C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            children: [
              Text(
                t("fitbit_scores_title"),
                style: AppTextStyles.subtitle.copyWith(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: t("fitbit_scores_readiness"),
            value: _fmtScore(summary?.readinessScore),
          ),
          _MetricRow(
            label: t("fitbit_scores_stress"),
            value: _fmtScore(summary?.stressManagementScore),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _fmtScore(int? value) => value == null ? "—" : "$value%";
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
