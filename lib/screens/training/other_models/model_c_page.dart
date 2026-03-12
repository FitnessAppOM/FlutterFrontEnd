import 'package:flutter/material.dart';
import '../../../widgets/cardio/cardio_map.dart';
import 'other_model_widgets.dart';

class ModelCPage extends StatelessWidget {
  const ModelCPage({
    super.key,
    required this.route,
    required this.durationLabel,
    required this.distanceLabel,
    required this.paceLabel,
    required this.userName,
    required this.dateLabel,
    this.captureKey,
  });

  final List<CardioPoint> route;
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              children: [
                ModelHeader(
                  appName: "Taqa Fitness",
                  userName: userName,
                  dateLabel: dateLabel,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TraceRow(route: route),
                      ModelMetricPill(label: "Duration", value: durationLabel),
                      ModelMetricPill(label: "Distance", value: distanceLabel),
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
      children: [
        Expanded(child: _TraceBox(route: route)),
      ],
    );
  }
}
