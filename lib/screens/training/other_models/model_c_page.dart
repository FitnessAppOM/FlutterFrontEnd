import 'package:flutter/material.dart';
import '../../../widgets/cardio/cardio_map.dart';
import '../../../TaqaUI/styles/taqa_ui_scale.dart';
import 'other_model_widgets.dart';

class ModelCPage extends StatelessWidget {
  const ModelCPage({
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
      padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
      child: RepaintBoundary(
        key: captureKey,
        child: ClipRRect(
          borderRadius: TaqaUiScale.radius(20),
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(14, 15, 14, 15),
            child: Column(
              children: [
                ModelHeader(
                  appName: "Taqa Fitness",
                  userName: userName,
                  dateLabel: dateLabel,
                ),
                SizedBox(height: TaqaUiScale.h(15)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TraceRow(route: route),
                      ModelMetricPill(label: "Duration", value: durationLabel),
                      if (showDistance)
                        ModelMetricPill(
                          label: "Distance",
                          value: distanceLabel,
                        ),
                      ModelMetricPill(label: "Pace", value: paceLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TraceBox extends StatelessWidget {
  const _TraceBox({required this.route});

  final List<CardioPoint> route;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.8,
      child: RouteTraceCanvas(
        route: route,
        showMarkers: false,
        lineWidth: 3.5,
        padding: 8,
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.route});

  final List<CardioPoint> route;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Expanded(child: _TraceBox(route: route))],
    );
  }
}
