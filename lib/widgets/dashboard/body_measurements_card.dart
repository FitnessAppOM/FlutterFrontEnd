import 'package:flutter/material.dart';
import '../../TaqaUI/components/taqa_progress_widget_card.dart';
import '../../localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context).translate;
    final heightLabel =
        heightCm == null ? "—" : "${heightCm!.toStringAsFixed(0)} cm";
    final weightLabel =
        weightKg == null ? "—" : "${weightKg!.toStringAsFixed(0)} ${t("unit_kg")}";

    return TaqaProgressWidgetCard(
      title: t("body_card_title"),
      valueText: heightLabel,
      goalText: t("body_weight_value").replaceAll("{value}", weightLabel),
      progress: 0.0,
      showArc: false,
      onTap: onTap,
    );
  }
}
