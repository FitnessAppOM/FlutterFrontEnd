import 'package:flutter/widgets.dart';

import '../../core/account_storage.dart';
import '../core/navigation_service.dart';
import '../../widgets/screening/screening_form_sheet.dart';
import 'screening_service.dart';

class ScreeningPromptService {
  static bool _isChecking = false;
  static bool _isShowing = false;
  static DateTime? _lastCheckAt;

  static Future<void> checkAndPromptIfDue() async {
    if (_isChecking || _isShowing) return;
    final now = DateTime.now();
    if (_lastCheckAt != null &&
        now.difference(_lastCheckAt!) < const Duration(seconds: 2)) {
      return;
    }

    _isChecking = true;
    _lastCheckAt = now;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;

      final pending = await ScreeningApi.checkPending(userId);
      if (!pending.isDue) return;

      final context = NavigationService.navigatorKey.currentContext;
      if (context == null) return;

      _isShowing = true;
      try {
        await ScreeningFormSheet.show(context, pending);
      } finally {
        _isShowing = false;
      }
    } catch (_) {
      // Keep app-open flow resilient; skip prompt on transient failures.
    } finally {
      _isChecking = false;
    }
  }
}
