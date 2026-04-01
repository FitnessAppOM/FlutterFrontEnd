import 'package:flutter/material.dart';

import '../../services/health/health_recovery_load_service.dart';
import '../../theme/app_theme.dart';

class HealthRecoveryLoadSheet extends StatelessWidget {
  const HealthRecoveryLoadSheet({
    super.key,
    required this.summary,
    required this.date,
  });

  final HealthRecoveryLoadSummary? summary;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final zones = summary?.zones;
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
                "Recovery & load",
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
            label: "Resting heart rate",
            value: summary?.restingHeartRate == null
                ? "—"
                : "${summary!.restingHeartRate} bpm",
          ),
          _MetricRow(
            label: "HRV",
            value: summary?.hrvMs == null
                ? "—"
                : "${summary!.hrvMs!.toStringAsFixed(0)} ms",
          ),
          _MetricRow(
            label: "Active minutes",
            value: summary?.activeMinutes == null
                ? "—"
                : "${summary!.activeMinutes} min",
          ),
          if (zones != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Heart rate zones (minutes)",
                style: AppTextStyles.small.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            _MetricRow(
              label: "Out of range",
              value: "${zones.outOfRangeMinutes} min",
            ),
            _MetricRow(label: "Fat burn", value: "${zones.fatBurnMinutes} min"),
            _MetricRow(label: "Cardio", value: "${zones.cardioMinutes} min"),
            _MetricRow(label: "Peak", value: "${zones.peakMinutes} min"),
          ],
          if (summary == null || !summary!.hasAnyData) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "No data available for this day from HealthKit/Health Connect.",
                style: AppTextStyles.small.copyWith(color: Colors.white60),
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

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
              style: AppTextStyles.small.copyWith(color: Colors.white70),
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
