import 'package:flutter/material.dart';
import '../../../widgets/cardio/cardio_map.dart';
import '../../../TaqaUI/styles/taqa_ui_scale.dart';
import 'other_model_widgets.dart';

class ModelBPage extends StatelessWidget {
  const ModelBPage({
    super.key,
    required this.route,
    required this.durationLabel,
    required this.showDistance,
    required this.distanceLabel,
    required this.paceLabel,
    required this.userName,
    required this.dateLabel,
    this.elevationLabel,
    this.captureKey,
  });

  final List<CardioPoint> route;
  final String durationLabel;
  final bool showDistance;
  final String distanceLabel;
  final String paceLabel;
  final String? userName;
  final String dateLabel;
  final String? elevationLabel;
  final GlobalKey? captureKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
      child: RepaintBoundary(
        key: captureKey,
        child: ClipRRect(
          borderRadius: TaqaUiScale.radius(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RouteTraceCanvas(route: route, showMarkers: true),
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
                    elevationLabel: elevationLabel,
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
