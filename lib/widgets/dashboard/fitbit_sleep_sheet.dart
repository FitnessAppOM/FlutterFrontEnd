import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/fitbit/fitbit_sleep_service.dart';

class FitbitSleepSheet extends StatelessWidget {
  final FitbitSleepSummary? summary;
  final DateTime date;

  const FitbitSleepSheet({
    super.key,
    required this.summary,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final logs = summary?.logs ?? const [];
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
              Text("Fitbit sleep",
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
            label: "Total sleep",
            value: summary?.totalMinutesAsleep == null
                ? "—"
                : _fmtMinutes(summary!.totalMinutesAsleep!),
          ),
          _MetricRow(
            label: "Time in bed",
            value: summary?.totalTimeInBed == null
                ? "—"
                : _fmtMinutes(summary!.totalTimeInBed!),
          ),
          _MetricRow(
            label: "Sleep goal",
            value: summary?.sleepGoalMinutes == null
                ? "—"
                : _fmtMinutes(summary!.sleepGoalMinutes!),
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Sleep logs",
                style: AppTextStyles.small.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            for (final log in logs) _LogRow(log: log),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "${h}h ${m}m";
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

class _LogRow extends StatelessWidget {
  final FitbitSleepLog log;

  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final start = log.start?.toLocal();
    final end = log.end?.toLocal();
    final startLabel = start == null ? "—" : "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    final endLabel = end == null ? "—" : "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
    final duration = log.minutesAsleep == null ? "—" : "${log.minutesAsleep} min";
    final main = log.isMainSleep == true ? "Main sleep" : "Nap/other";

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
            child: Text(
              "$startLabel → $endLabel",
              style: AppTextStyles.small.copyWith(color: Colors.white70),
            ),
          ),
          Text(
            duration,
            style: AppTextStyles.small.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            main,
            style: AppTextStyles.small.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
