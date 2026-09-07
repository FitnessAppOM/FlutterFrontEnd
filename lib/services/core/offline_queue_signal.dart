import 'package:flutter/foundation.dart';

/// Lightweight signal shared by durable queues without creating imports
/// between feature queues and the synchronization coordinator.
class OfflineQueueSignal {
  OfflineQueueSignal._();

  static final ValueNotifier<int> change = ValueNotifier<int>(0);

  static void notifyChanged() => change.value++;
}
