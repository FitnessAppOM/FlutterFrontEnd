import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';

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

    return TaqaProgressWidgetCard(
      title: "Body",
      valueText: heightLabel,
      goalText: "Weight $weightLabel",
      progress: 0.0,
      showArc: false,
      onTap: onTap,
    );
  }
}
