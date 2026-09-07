import 'dart:async';

import 'package:flutter/foundation.dart';

import '../training/cardio_session_queue.dart';
import '../training/exercise_action_queue.dart';
import '../diet/diet_action_queue.dart';
import '../metrics/daily_journal_action_queue.dart';
import 'network_status_service.dart';
import 'offline_queue_signal.dart';

enum OfflineSyncStatus { idle, syncing, succeeded, failed }

class OfflineSyncCoordinator extends ChangeNotifier {
  OfflineSyncCoordinator._();

  static final OfflineSyncCoordinator instance = OfflineSyncCoordinator._();

  final NetworkStatusService _network = NetworkStatusService.instance;
  bool _initialized = false;
  bool _wasOffline = false;
  Future<void>? _syncInFlight;
  Timer? _successTimer;
  OfflineSyncStatus _status = OfflineSyncStatus.idle;
  int _pendingCount = 0;

  OfflineSyncStatus get status => _status;
  int get pendingCount => _pendingCount;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _wasOffline = _network.isOffline;
    _network.addListener(_handleNetworkChanged);
    OfflineQueueSignal.change.addListener(_handleQueueChanged);
    await refreshPendingCount();
    if (_network.isOnline && _pendingCount > 0) {
      unawaited(syncNow(showSuccess: true));
    }
  }

  void _handleQueueChanged() => unawaited(refreshPendingCount());

  void _handleNetworkChanged() {
    if (_network.isOffline) {
      _wasOffline = true;
      return;
    }
    if (_network.isOnline && _wasOffline) {
      _wasOffline = false;
      unawaited(syncNow(showSuccess: true));
    }
  }

  Future<void> refreshPendingCount() async {
    final counts = await Future.wait<int>([
      ExerciseActionQueue.pendingCount(),
      CardioSessionQueue.pendingCount(),
      DailyJournalActionQueue.pendingCount(),
      DietActionQueue.pendingCount(),
    ]);
    final next = counts.fold<int>(0, (sum, count) => sum + count);
    if (_pendingCount == next) return;
    _pendingCount = next;
    notifyListeners();
  }

  Future<void> syncNow({bool showSuccess = false}) {
    final active = _syncInFlight;
    if (active != null) return active;
    final future = _runSync(showSuccess: showSuccess);
    _syncInFlight = future;
    future.whenComplete(() {
      if (identical(_syncInFlight, future)) _syncInFlight = null;
    });
    return future;
  }

  Future<void> _runSync({required bool showSuccess}) async {
    if (_network.isOffline) {
      await refreshPendingCount();
      return;
    }
    _successTimer?.cancel();
    _status = OfflineSyncStatus.syncing;
    notifyListeners();
    try {
      await ExerciseActionQueue.syncQueue();
      await CardioSessionQueue.syncQueue();
      await DailyJournalActionQueue.syncQueue();
      await DietActionQueue.syncQueue();
      await refreshPendingCount();
      if (_pendingCount > 0) {
        _status = OfflineSyncStatus.failed;
      } else if (showSuccess) {
        _status = OfflineSyncStatus.succeeded;
        _successTimer = Timer(const Duration(seconds: 3), () {
          _status = OfflineSyncStatus.idle;
          notifyListeners();
        });
      } else {
        _status = OfflineSyncStatus.idle;
      }
    } catch (_) {
      await refreshPendingCount();
      _status = OfflineSyncStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _network.removeListener(_handleNetworkChanged);
    OfflineQueueSignal.change.removeListener(_handleQueueChanged);
    super.dispose();
  }
}
