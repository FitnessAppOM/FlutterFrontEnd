import 'dart:async';
import 'dart:io';

import '../localization/app_localizations.dart';
import 'locale_controller.dart';

String userFriendlyErrorMessage(Object error, {String? fallback}) {
  final t = AppLocalizations(localeController.locale);
  final fallbackText = fallback ?? t.translate('error_generic');
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw.isEmpty) return fallbackText;

  if (_looksLikeNetworkError(error, raw)) {
    return t.translate('error_connection');
  }

  if (raw.toLowerCase().startsWith('clientexception:')) {
    final cleaned = raw.substring('clientexception:'.length).trim();
    if (cleaned.isEmpty) return fallbackText;
    return _localizedKnownError(t, cleaned) ?? cleaned;
  }

  return _localizedKnownError(t, raw) ?? raw;
}

String? _localizedKnownError(AppLocalizations t, String message) {
  switch (message.trim().toLowerCase()) {
    case 'failed to delete account':
    case 'could not delete account. please try again.':
      return t.translate('settings_delete_account_failed');
    case 'failed to deactivate account':
    case 'could not deactivate account. please try again.':
      return t.translate('settings_deactivate_account_failed');
    case 'account can no longer be restored':
      return t.translate('account_restore_expired');
    case 'account not found':
      return t.translate('account_not_found');
    case 'request failed':
      return t.translate('account_request_failed');
    case 'reactivation failed':
      return t.translate('account_restore_failed');
    case 'something went wrong. please try again.':
      return t.translate('error_generic');
    case "couldn't connect. check your internet and try again.":
      return t.translate('error_connection');
  }
  return null;
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
