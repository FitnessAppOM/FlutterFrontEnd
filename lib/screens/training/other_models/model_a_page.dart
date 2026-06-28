import 'package:flutter/material.dart';
import '../../../TaqaUI/styles/taqa_ui_scale.dart';
import 'other_model_widgets.dart';

class ModelAPage extends StatelessWidget {
  const ModelAPage({
    super.key,
    required this.snapshotUrl,
    required this.durationLabel,
    required this.showDistance,
    required this.distanceLabel,
    required this.paceLabel,
    required this.userName,
    required this.dateLabel,
    this.captureKey,
  });

  final String snapshotUrl;
  final String durationLabel;
  final bool showDistance;
  final String distanceLabel;
  final String paceLabel;
  final String? userName;
  final String dateLabel;
  final GlobalKey? captureKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
      child: RepaintBoundary(
        key: captureKey,
        child: ModelMapCard(
          snapshotUrl: snapshotUrl,
          overlay: Stack(
            children: [
              Positioned(
                top: TaqaUiScale.h(14),
                left: TaqaUiScale.w(14),
                right: TaqaUiScale.w(14),
                child: ModelHeader(
                  appName: "Taqa Fitness",
                  userName: userName,
                  dateLabel: dateLabel,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(top: TaqaUiScale.h(80)),
                  child: ModelMetricsColumn(
                    durationLabel: durationLabel,
                    showDistance: showDistance,
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
