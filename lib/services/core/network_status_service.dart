import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/user_friendly_error.dart';

enum TaqaNetworkStatus { unknown, online, offline }

/// App-wide connectivity state.
///
/// A network interface is only a hint. Whenever an interface becomes
/// available we also make a small request to the public app-version endpoint.
/// Feature requests are still always guarded by their own error handling.
class NetworkStatusService extends ChangeNotifier {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounce;
  Future<void>? _probeInFlight;
  bool _initialized = false;
  TaqaNetworkStatus _status = TaqaNetworkStatus.unknown;

  TaqaNetworkStatus get status => _status;
  bool get isOnline => _status == TaqaNetworkStatus.online;
  bool get isOffline => _status == TaqaNetworkStatus.offline;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _connectivity.onConnectivityChanged.listen(
      _scheduleConnectivityCheck,
    );
    try {
      final results = await _connectivity.checkConnectivity();
      if (_hasInterface(results)) {
        await _probeBackend();
      } else {
        _setStatus(TaqaNetworkStatus.offline);
      }
    } catch (_) {
      // A plugin failure must not block startup. The first real request will
      // report a transport failure if the device is actually offline.
    }
  }

  Future<void> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (_hasInterface(results)) {
        await _probeBackend();
      } else {
        _setStatus(TaqaNetworkStatus.offline);
      }
    } catch (_) {
      await _probeBackend();
    }
  }

  bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  void _scheduleConnectivityCheck(List<ConnectivityResult> results) {
    _debounce?.cancel();
    if (!_hasInterface(results)) {
      _setStatus(TaqaNetworkStatus.offline);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      await _probeBackend();
    });
  }

  Future<void> _probeBackend() {
    final active = _probeInFlight;
    if (active != null) return active;
    final future = _runProbe();
    _probeInFlight = future;
    future.whenComplete(() {
      if (identical(_probeInFlight, future)) _probeInFlight = null;
    });
    return future;
  }

  Future<void> _runProbe() async {
    try {
      // Any HTTP response proves that the server was reached. A server-side
      // error is not the same thing as the user being offline.
      await http
          .get(Uri.parse('${ApiConfig.baseUrl}/app/version'))
          .timeout(const Duration(seconds: 4));
      _setStatus(TaqaNetworkStatus.online);
    } catch (error) {
      if (isNetworkError(error)) {
        _setStatus(TaqaNetworkStatus.offline);
      }
    }
  }

  void reportNetworkFailure(Object error) {
    if (isNetworkError(error)) _setStatus(TaqaNetworkStatus.offline);
  }

  void reportServerReached() => _setStatus(TaqaNetworkStatus.online);

  void markOffline() => _setStatus(TaqaNetworkStatus.offline);

  void _setStatus(TaqaNetworkStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
