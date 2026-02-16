import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'training_foreground_task_handler.dart';

class TrainingActivityService {
  static bool _active = false;
  static int _lastUpdateSecond = -1;
  static const MethodChannel _liveActivityChannel = MethodChannel('training_live_activity');
  static String? _liveActivitySessionId;

  static String _buildTitle(String exerciseName) {
    return "Training • $exerciseName";
  }

  static String _buildBody({
    required int seconds,
    required int sets,
    required int reps,
  }) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "Timer $mm:$ss • $sets x $reps";
  }

  static Future<void> startSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
  }) async {
    if (!_active) {
      _active = true;
      _lastUpdateSecond = seconds;
      if (Platform.isIOS) {
        _liveActivitySessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await _startLiveActivity(
          exerciseName: exerciseName,
          sets: sets,
          reps: reps,
          seconds: seconds,
        );
      }
      await _startForegroundService(
        title: _buildTitle(exerciseName),
        body: _buildBody(seconds: seconds, sets: sets, reps: reps),
      );
      return;
    }
    await updateSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      seconds: seconds,
    );
  }

  static Future<void> updateSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
  }) async {
    if (!_active) return;
    if (seconds == _lastUpdateSecond) return;
    _lastUpdateSecond = seconds;

    if (Platform.isAndroid) {
      await FlutterForegroundTask.updateService(
        notificationTitle: _buildTitle(exerciseName),
        notificationText: _buildBody(seconds: seconds, sets: sets, reps: reps),
      );
    }
    if (Platform.isIOS) {
      await _updateLiveActivity(
        exerciseName: exerciseName,
        sets: sets,
        reps: reps,
        seconds: seconds,
      );
    }
  }

  static Future<void> stopSession() async {
    if (!_active) return;
    _active = false;
    _lastUpdateSecond = -1;
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
    if (Platform.isIOS) {
      await _stopLiveActivity();
    }
  }

  static Future<void> _startForegroundService({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: body,
      callback: trainingStartCallback,
    );
  }

  static Future<void> _startLiveActivity({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
  }) async {
    try {
      final ok = await _liveActivityChannel.invokeMethod('start', {
        'sessionId': _liveActivitySessionId,
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
      });
      // ignore: avoid_print
      print('[LiveActivity] start result: $ok');
    } catch (_) {}
  }

  static Future<void> _updateLiveActivity({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
  }) async {
    try {
      final ok = await _liveActivityChannel.invokeMethod('update', {
        'sessionId': _liveActivitySessionId,
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
      });
      // ignore: avoid_print
      print('[LiveActivity] update result: $ok');
    } catch (_) {}
  }

  static Future<void> _stopLiveActivity() async {
    try {
      final ok = await _liveActivityChannel.invokeMethod('stop');
      // ignore: avoid_print
      print('[LiveActivity] stop result: $ok');
    } catch (_) {}
    _liveActivitySessionId = null;
  }
}
