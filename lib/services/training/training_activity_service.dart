import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'training_foreground_task_handler.dart';

class TrainingActivityService {
  static bool _active = false;
  static int _lastUpdateSecond = -1;
  static double? _lastDistanceKm;
  static double? _lastPaceMinKm;
  static const MethodChannel _liveActivityChannel = MethodChannel('training_live_activity');
  static String? _liveActivitySessionId;
  static int? _sessionStartMs;
  static const _kSessionActive = 'training_session_active';
  static const _kSessionStartMs = 'training_session_start_ms';
  static const _kSessionName = 'training_session_name';
  static const _kSessionSets = 'training_session_sets';
  static const _kSessionReps = 'training_session_reps';
  static const _kSessionDistance = 'training_session_distance';
  static const _kSessionPace = 'training_session_speed';
  static const _kSessionPaused = 'training_session_paused';
  static const _kSessionPausedSeconds = 'training_session_paused_seconds';

  static String _buildTitle(String exerciseName) {
    return "Training • $exerciseName";
  }

  static String _buildBody({
    required int seconds,
    required int sets,
    required int reps,
    double? distanceKm,
    double? paceMinKm,
  }) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    if (distanceKm != null || paceMinKm != null) {
      final d = (distanceKm ?? 0).toStringAsFixed(2);
      final pace = _paceLabel(paceMinKm);
      return "Timer $mm:$ss • $d km • $pace";
    }
    return "Timer $mm:$ss • $sets x $reps";
  }

  static String _paceLabel(double? paceMinKm) {
    if (paceMinKm == null || paceMinKm <= 0.1) return "--:-- /km";
    final paceMin = paceMinKm;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    final mm = paceMinutes.toString().padLeft(2, '0');
    final ss = paceSeconds.toString().padLeft(2, '0');
    return "$mm:$ss /km";
  }

  static Future<void> startSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
    double? distanceKm,
    double? paceMinKm,
  }) async {
    if (!_active) {
      _active = true;
      _lastUpdateSecond = seconds;
      _sessionStartMs ??= DateTime.now().millisecondsSinceEpoch;
      await _persistSession(
        exerciseName: exerciseName,
        sets: sets,
        reps: reps,
        distanceKm: distanceKm,
        paceMinKm: paceMinKm,
        startMs: _sessionStartMs!,
      );
      if (Platform.isIOS) {
        _liveActivitySessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await _startLiveActivity(
          exerciseName: exerciseName,
          sets: sets,
          reps: reps,
          seconds: seconds,
          distanceKm: distanceKm,
          paceMinKm: paceMinKm,
          startMs: _sessionStartMs,
          paused: false,
        );
      }
      await _startForegroundService(
        title: _buildTitle(exerciseName),
        body: _buildBody(
          seconds: seconds,
          sets: sets,
          reps: reps,
          distanceKm: distanceKm,
          paceMinKm: paceMinKm,
        ),
      );
      return;
    }
    await updateSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      seconds: seconds,
      distanceKm: distanceKm,
      paceMinKm: paceMinKm,
      startMs: _sessionStartMs,
    );
  }

  static Future<void> updateSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
    double? distanceKm,
    double? paceMinKm,
    int? startMs,
  }) async {
    if (!_active) return;
    final distanceChanged = _hasSignificantDelta(_lastDistanceKm, distanceKm, 0.01);
    final paceChanged = _hasSignificantDelta(_lastPaceMinKm, paceMinKm, 0.1);
    if (seconds == _lastUpdateSecond && !distanceChanged && !paceChanged) return;
    _lastUpdateSecond = seconds;
    _lastDistanceKm = distanceKm ?? _lastDistanceKm;
    _lastPaceMinKm = paceMinKm ?? _lastPaceMinKm;
    _sessionStartMs ??= startMs;
    await _setPaused(false, null);
    await _persistSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      distanceKm: distanceKm,
      paceMinKm: paceMinKm,
    );

    if (Platform.isAndroid) {
      await FlutterForegroundTask.updateService(
        notificationTitle: _buildTitle(exerciseName),
        notificationText: _buildBody(
          seconds: seconds,
          sets: sets,
          reps: reps,
          distanceKm: distanceKm,
          paceMinKm: paceMinKm,
        ),
      );
    }
    if (Platform.isIOS) {
      await _updateLiveActivity(
        exerciseName: exerciseName,
        sets: sets,
        reps: reps,
        seconds: seconds,
        distanceKm: distanceKm,
        paceMinKm: paceMinKm,
        startMs: _sessionStartMs,
        paused: false,
      );
    }
  }

  static Future<void> stopSession() async {
    if (!_active) {
      await _clearSession();
      return;
    }
    _active = false;
    _lastUpdateSecond = -1;
    _lastDistanceKm = null;
    _lastPaceMinKm = null;
    _sessionStartMs = null;
    await _clearSession();
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
    if (Platform.isIOS) {
      await _stopLiveActivity();
    }
  }

  static Future<void> pauseSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
    double? distanceKm,
    double? paceMinKm,
  }) async {
    if (!_active) return;
    _lastUpdateSecond = seconds;
    _lastDistanceKm = distanceKm ?? _lastDistanceKm;
    _lastPaceMinKm = paceMinKm ?? _lastPaceMinKm;
    await _setPaused(true, seconds);
    await _persistSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      distanceKm: distanceKm,
      paceMinKm: paceMinKm,
      startMs: null,
    );

    if (Platform.isAndroid) {
      await FlutterForegroundTask.updateService(
        notificationTitle: _buildTitle(exerciseName),
        notificationText: _buildBody(
          seconds: seconds,
          sets: sets,
          reps: reps,
          distanceKm: distanceKm,
          paceMinKm: paceMinKm,
        ),
      );
    }
    if (Platform.isIOS) {
      await _updateLiveActivity(
        exerciseName: exerciseName,
        sets: sets,
        reps: reps,
        seconds: seconds,
        distanceKm: distanceKm,
        paceMinKm: paceMinKm,
        startMs: null,
        paused: true,
      );
    }
  }

  static Future<void> resumeSession({
    required String exerciseName,
    required int sets,
    required int reps,
    required int seconds,
    double? distanceKm,
    double? paceMinKm,
  }) async {
    if (!_active) return;
    _lastUpdateSecond = seconds;
    _lastDistanceKm = distanceKm ?? _lastDistanceKm;
    _lastPaceMinKm = paceMinKm ?? _lastPaceMinKm;
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch - (seconds * 1000);
    await _setPaused(false, null);
    await _persistSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      distanceKm: distanceKm,
      paceMinKm: paceMinKm,
      startMs: _sessionStartMs,
    );
    await updateSession(
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      seconds: seconds,
      distanceKm: distanceKm,
      paceMinKm: paceMinKm,
      startMs: _sessionStartMs,
    );
  }

  static Future<Map<String, dynamic>?> getActiveSession() async {
    final sp = await SharedPreferences.getInstance();
    final active = sp.getBool(_kSessionActive) ?? false;
    if (!active) return null;
    return {
      'startMs': sp.getInt(_kSessionStartMs),
      'name': sp.getString(_kSessionName),
      'sets': sp.getInt(_kSessionSets),
      'reps': sp.getInt(_kSessionReps),
      'distanceKm': sp.getDouble(_kSessionDistance),
      'paceMinKm': sp.getDouble(_kSessionPace),
      'paused': sp.getBool(_kSessionPaused) ?? false,
      'pausedSeconds': sp.getInt(_kSessionPausedSeconds),
    };
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
    double? distanceKm,
    double? paceMinKm,
    int? startMs,
    required bool paused,
  }) async {
    try {
      final ok = await _liveActivityChannel.invokeMethod('start', {
        'sessionId': _liveActivitySessionId,
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
        'distanceKm': distanceKm,
        'speedKmh': paceMinKm,
        'startMs': startMs,
        'paused': paused,
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
    double? distanceKm,
    double? paceMinKm,
    int? startMs,
    required bool paused,
  }) async {
    try {
      final ok = await _liveActivityChannel.invokeMethod('update', {
        'sessionId': _liveActivitySessionId,
        'exerciseName': exerciseName,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
        'distanceKm': distanceKm,
        'speedKmh': paceMinKm,
        'startMs': startMs,
        'paused': paused,
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

  static Future<void> _persistSession({
    required String exerciseName,
    required int sets,
    required int reps,
    double? distanceKm,
    double? paceMinKm,
    int? startMs,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSessionActive, true);
    if (startMs != null) {
      await sp.setInt(_kSessionStartMs, startMs);
    } else if (!sp.containsKey(_kSessionStartMs)) {
      await sp.setInt(_kSessionStartMs, DateTime.now().millisecondsSinceEpoch);
    }
    await sp.setString(_kSessionName, exerciseName);
    await sp.setInt(_kSessionSets, sets);
    await sp.setInt(_kSessionReps, reps);
    if (distanceKm != null) {
      await sp.setDouble(_kSessionDistance, distanceKm);
    }
    if (paceMinKm != null) {
      await sp.setDouble(_kSessionPace, paceMinKm);
    }
  }

  static Future<void> _setPaused(bool paused, int? seconds) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSessionPaused, paused);
    if (seconds != null) {
      await sp.setInt(_kSessionPausedSeconds, seconds);
    } else {
      await sp.remove(_kSessionPausedSeconds);
    }
  }

  static Future<void> _clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSessionActive);
    await sp.remove(_kSessionStartMs);
    await sp.remove(_kSessionName);
    await sp.remove(_kSessionSets);
    await sp.remove(_kSessionReps);
    await sp.remove(_kSessionDistance);
    await sp.remove(_kSessionPace);
    await sp.remove(_kSessionPaused);
    await sp.remove(_kSessionPausedSeconds);
  }

  static bool _hasSignificantDelta(double? prev, double? next, double threshold) {
    if (next == null) return false;
    if (prev == null) return true;
    return (next - prev).abs() >= threshold;
  }
}
