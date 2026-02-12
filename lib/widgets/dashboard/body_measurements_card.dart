import 'package:flutter/material.dart';
import '../../widgets/dashboard/stat_card.dart';

class BodyMeasurementsCard extends StatelessWidget {
  final double? heightCm;
  final double? weightKg;
  final VoidCallback? onTap;

  const BodyMeasurementsCard({
    super.key,
    required this.heightCm,
    required this.weightKg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final heightLabel =
        heightCm == null ? "—" : "${heightCm!.toStringAsFixed(0)} cm";
    final weightLabel =
        weightKg == null ? "—" : "${weightKg!.toStringAsFixed(0)} kg";

    return StatCard(
      title: "Body",
      value: heightLabel,
      subtitle: "Weight $weightLabel",
      icon: Icons.person,
      accentColor: const Color(0xFF6A5AE0),
      onTap: onTap,
    );
  }
}
