import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FitbitHeartSheet extends StatelessWidget {
  final int? restingHr;
  final double? hrvRmssd;
  final String? vo2Max;
  final List<dynamic> zones;
  final DateTime date;

  const FitbitHeartSheet({
    super.key,
    required this.restingHr,
    required this.hrvRmssd,
    required this.vo2Max,
    required this.zones,
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
              Text("Heart & cardio",
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
            label: "Resting heart rate",
            value: restingHr == null ? "—" : "${restingHr} bpm",
          ),
          _MetricRow(
            label: "HRV (RMSSD)",
            value: hrvRmssd == null ? "—" : "${hrvRmssd!.toStringAsFixed(0)} ms",
          ),
          _MetricRow(
            label: "Cardio fitness (VO₂ max)",
            value: vo2Max == null || vo2Max!.isEmpty ? "—" : vo2Max!,
          ),
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Heart rate zones",
                style: AppTextStyles.small.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            for (final z in zones) _ZoneRow(zone: z),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

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

class _ZoneRow extends StatelessWidget {
  final dynamic zone;

  const _ZoneRow({required this.zone});

  @override
  Widget build(BuildContext context) {
    String name = "Zone";
    String range = "—";
    String minutes = "—";
    if (zone is Map) {
      final z = zone as Map;
      name = z["name"]?.toString() ?? name;
      final min = z["min"]?.toString();
      final max = z["max"]?.toString();
      if (min != null && max != null) range = "$min-$max bpm";
      final mins = z["minutes"]?.toString();
      if (mins != null) minutes = "$mins min";
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: AppTextStyles.small.copyWith(color: Colors.white70)),
          ),
          Text(
            range,
            style: AppTextStyles.small.copyWith(color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Text(
            minutes,
            style: AppTextStyles.small.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
