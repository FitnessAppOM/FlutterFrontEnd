import 'dart:async';
import 'dart:io';

String userFriendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw.isEmpty) return fallback;

  if (_looksLikeNetworkError(error, raw)) {
    return "Couldn't connect. Check your internet and try again.";
  }

  if (raw.toLowerCase().startsWith('clientexception:')) {
    final cleaned = raw.substring('clientexception:'.length).trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  return raw;
}

bool _looksLikeNetworkError(Object error, String message) {
  if (error is SocketException || error is TimeoutException) return true;

  final lower = message.toLowerCase();
  const markers = <String>[
    'socketexception',
    'clientexception',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection abort',
    'connection timed out',
    'timed out',
    'dns',
    'unable to resolve host',
    'no address associated with hostname',
    'error connecting',
    'could not connect',
  ];

  return markers.any(lower.contains);
}
