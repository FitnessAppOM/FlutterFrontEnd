import 'package:flutter/material.dart';
import '../../main/main_layout.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool launchedFromNotificationPayload = false;
  static bool _dietNotificationPending = false;

  static Future<void> navigateToJournal({bool fromNotification = false}) async {
    if (fromNotification) {
      launchedFromNotificationPayload = true;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Use pushNamed to allow back navigation to previous stack.
    nav.pushNamed('/daily-journal');
  }

  static Future<void> navigateToDiet({bool fromNotification = false}) async {
    if (fromNotification) {
      _dietNotificationPending = true;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Reset to main layout and select the Diet tab.
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 2)),
      (_) => false,
    );
  }


  static bool consumeDietNotification() {
    final pending = _dietNotificationPending;
    _dietNotificationPending = false;
    return pending;
  }
}
