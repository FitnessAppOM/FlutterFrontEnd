import 'package:flutter/material.dart';
import '../../../widgets/cardio/cardio_map.dart';
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
    this.captureKey,
  });

  final List<CardioPoint> route;
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
      padding: const EdgeInsets.all(12),
      child: RepaintBoundary(
        key: captureKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RouteTraceCanvas(route: route, showMarkers: true),
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
