import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingForegroundTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    final sp = await SharedPreferences.getInstance();
    final active = sp.getBool('training_session_active') ?? false;
    if (!active) return;
    final paused = sp.getBool('training_session_paused') ?? false;
    final pausedSeconds = sp.getInt('training_session_paused_seconds');
    final startMs = sp.getInt('training_session_start_ms') ?? timestamp.millisecondsSinceEpoch;
    final elapsedSec = paused
        ? (pausedSeconds ?? 0)
        : ((timestamp.millisecondsSinceEpoch - startMs) / 1000).round();
    final name = sp.getString('training_session_name') ?? 'Training';
    final sets = sp.getInt('training_session_sets') ?? 0;
    final reps = sp.getInt('training_session_reps') ?? 0;
    final distance = sp.getDouble('training_session_distance');
    final speed = sp.getDouble('training_session_speed');

    final mm = (elapsedSec ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSec % 60).toString().padLeft(2, '0');
    final body = (distance != null || speed != null)
        ? 'Timer $mm:$ss • ${(distance ?? 0).toStringAsFixed(2)} km • ${_paceLabel(speed)}'
        : 'Timer $mm:$ss • $sets x $reps';

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Training • $name',
      notificationText: body,
    );
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("/");
  }

  String _paceLabel(double? speedKmh) {
    if (speedKmh == null || speedKmh <= 0.1) return "--:-- /km";
    final paceMin = 60.0 / speedKmh;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    final mm = paceMinutes.toString().padLeft(2, '0');
    final ss = paceSeconds.toString().padLeft(2, '0');
    return "$mm:$ss /km";
  }
}

@pragma('vm:entry-point')
void trainingStartCallback() {
  FlutterForegroundTask.setTaskHandler(TrainingForegroundTaskHandler());
}
