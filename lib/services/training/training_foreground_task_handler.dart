import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_notification_copy.dart';

class TrainingForegroundTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    final sp = await SharedPreferences.getInstance();
    await sp.reload();
    final active = sp.getBool('training_session_active') ?? false;
    if (!active) return;
    final paused = sp.getBool('training_session_paused') ?? false;
    final pausedSeconds = sp.getInt('training_session_paused_seconds');
    final startMs =
        sp.getInt('training_session_start_ms') ??
        timestamp.millisecondsSinceEpoch;
    final elapsedSec = paused
        ? (pausedSeconds ?? 0)
        : ((timestamp.millisecondsSinceEpoch - startMs) / 1000).round();
    final languageCode =
        sp.getString('training_session_language_code') ??
        sp.getString('app_language_code') ??
        'en';
    final name =
        sp.getString('training_session_name') ??
        TrainingNotificationCopy.text(languageCode, 'training_workout');
    final sets = sp.getInt('training_session_sets') ?? 0;
    final reps = sp.getInt('training_session_reps') ?? 0;
    final distance = sp.getDouble('training_session_distance');
    final paceMinKm = sp.getDouble('training_session_speed');
    final avgPaceMinKm = _avgPaceMinKm(distance, elapsedSec) ?? paceMinKm;

    final mm = (elapsedSec ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSec % 60).toString().padLeft(2, '0');
    final time = '$mm:$ss';
    final body = (distance != null || paceMinKm != null)
        ? TrainingNotificationCopy.cardioBody(
            languageCode,
            time: time,
            distance: (distance ?? 0).toStringAsFixed(2),
            pace: _paceLabel(avgPaceMinKm, languageCode),
          )
        : TrainingNotificationCopy.timerBody(
            languageCode,
            time: time,
            sets: sets,
            reps: reps,
          );

    await FlutterForegroundTask.updateService(
      notificationTitle: TrainingNotificationCopy.title(languageCode, name),
      notificationText: body,
    );
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("/");
  }

  double? _avgPaceMinKm(double? distanceKm, int seconds) {
    if (distanceKm == null || distanceKm <= 0.001) return null;
    if (seconds <= 0) return null;
    return (seconds / 60.0) / distanceKm;
  }

  String _paceLabel(double? paceMinKm, String languageCode) {
    final unit = TrainingNotificationCopy.text(
      languageCode,
      'training_pace_unit',
    );
    if (paceMinKm == null || paceMinKm <= 0.1) return "--:-- $unit";
    final paceMin = paceMinKm;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    final mm = paceMinutes.toString().padLeft(2, '0');
    final ss = paceSeconds.toString().padLeft(2, '0');
    return "$mm:$ss $unit";
  }
}

@pragma('vm:entry-point')
void trainingStartCallback() {
  FlutterForegroundTask.setTaskHandler(TrainingForegroundTaskHandler());
}
