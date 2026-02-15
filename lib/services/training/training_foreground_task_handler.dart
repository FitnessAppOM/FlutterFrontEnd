import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class TrainingForegroundTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("/");
  }
}

@pragma('vm:entry-point')
void trainingStartCallback() {
  FlutterForegroundTask.setTaskHandler(TrainingForegroundTaskHandler());
}
