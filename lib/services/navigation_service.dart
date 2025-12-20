import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool launchedFromNotificationPayload = false;

  static Future<void> navigateToJournal({bool fromNotification = false}) async {
    if (fromNotification) {
      launchedFromNotificationPayload = true;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Use pushNamed to allow back navigation to previous stack.
    nav.pushNamed('/daily-journal');
  }
}
