import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/fitbit/fitbit_activity_service.dart';

class FitbitDailyActivitySheet extends StatelessWidget {
  final FitbitActivitySummary summary;
  final DateTime date;

  const FitbitDailyActivitySheet({
    super.key,
    required this.summary,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
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
              Text("Daily activity",
                  style: AppTextStyles.subtitle.copyWith(color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetricRow(
            label: "Steps",
            value: summary.steps?.toString() ?? "—",
            goal: summary.goalSteps,
            unit: "",
          ),
          _MetricRow(
            label: "Distance",
            value: summary.distance?.toStringAsFixed(1) ?? "—",
            goal: summary.goalDistance,
            unit: "km",
          ),
          _MetricRow(
            label: "Calories",
            value: summary.calories?.toString() ?? "—",
            goal: summary.goalCalories,
            unit: "kcal",
          ),
          _MetricRow(
            label: "Floors",
            value: summary.floors?.toString() ?? "—",
            goal: summary.goalFloors,
            unit: "",
          ),
          _MetricRow(
            label: "Active minutes",
            value: summary.activeMinutes?.toString() ?? "—",
            goal: summary.goalActiveMinutes,
            unit: "min",
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final num? goal;
  final String unit;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final double? v = double.tryParse(value);
    final double? g = goal == null ? null : (goal is num ? (goal as num).toDouble() : null);
    final progress = (v != null && g != null && g > 0) ? (v / g).clamp(0.0, 1.2) : null;
    final goalLabel = g == null ? "—" : "${g.toStringAsFixed(0)} $unit";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: AppTextStyles.small.copyWith(color: Colors.white70)),
              const Spacer(),
              Text(
                unit.isEmpty ? value : "$value $unit",
                style: AppTextStyles.subtitle.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            "Goal: $goalLabel",
            style: AppTextStyles.small.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
