import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class FitbitVitalsCard extends StatelessWidget {
  final bool loading;
  final double? spo2Percent;
  final double? skinTempC;
  final double? breathingRate;
  final String? ecgSummary;
  final int? ecgAvgHr;
  final VoidCallback? onTap;

  const FitbitVitalsCard({
    super.key,
    required this.loading,
    required this.spo2Percent,
    required this.skinTempC,
    required this.breathingRate,
    required this.ecgSummary,
    required this.ecgAvgHr,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fitbitDark = Color(0xFF0C6A73);
    final value = _buildValue();
    final subtitle = _buildSubtitle();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StatCard(
          title: "Fitbit health",
          value: value,
          subtitle: subtitle,
          icon: Icons.health_and_safety,
          accentColor: fitbitDark,
          borderColor: fitbitDark,
          borderWidth: 2.2,
          onTap: onTap,
        ),
        Positioned(
          top: -10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fitbitDark,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/fitbit.png',
              height: 14,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  String _buildValue() {
    if (loading) return "…";
    if (spo2Percent != null) return "SpO₂ ${spo2Percent!.toStringAsFixed(0)}%";
    if (breathingRate != null) return "BR ${breathingRate!.toStringAsFixed(1)}";
    if (skinTempC != null) return "Temp ${_fmtTemp(skinTempC!)}";
    if (ecgSummary != null) return "ECG ${ecgSummary!}";
    return "—";
  }

  String? _buildSubtitle() {
    if (loading) return null;
    final parts = <String>[];
    if (skinTempC != null) parts.add("Temp ${_fmtTemp(skinTempC!)}");
    if (breathingRate != null) parts.add("BR ${breathingRate!.toStringAsFixed(1)}");
    if (ecgSummary != null) {
      final hr = ecgAvgHr != null ? " ${ecgAvgHr} bpm" : "";
      parts.add("ECG $ecgSummary$hr");
    }
    return parts.isEmpty ? null : parts.join(" • ");
  }

  String _fmtTemp(double v) {
    final sign = v >= 0 ? "+" : "";
    return "$sign${v.toStringAsFixed(1)}°C";
  }
}
