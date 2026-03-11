import 'package:flutter/material.dart';
import 'other_model_widgets.dart';

class ModelAPage extends StatelessWidget {
  const ModelAPage({
    super.key,
    required this.snapshotUrl,
    required this.durationLabel,
    required this.distanceLabel,
    required this.paceLabel,
    required this.userName,
    required this.dateLabel,
    this.captureKey,
  });

  final String snapshotUrl;
  final String durationLabel;
  final String distanceLabel;
  final String paceLabel;
  final String? userName;
  final String dateLabel;
  final GlobalKey? captureKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: RepaintBoundary(
        key: captureKey,
        child: ModelMapCard(
          snapshotUrl: snapshotUrl,
          overlay: Stack(
            children: [
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: ModelHeader(
                  appName: "Taqa Fitness",
                  userName: userName,
                  dateLabel: dateLabel,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 90),
                  child: ModelMetricsColumn(
                    durationLabel: durationLabel,
                    distanceLabel: distanceLabel,
                    paceLabel: paceLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
