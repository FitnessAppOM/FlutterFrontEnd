import 'package:flutter/material.dart';
import '../../main/main_layout.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool launchedFromNotificationPayload = false;
  static bool isOnJournalPage = false;
  static bool _journalNotificationPending = false;
  static bool _dietNotificationPending = false;

  static bool get journalNotificationPending => _journalNotificationPending;
  static bool get dietNotificationPending => _dietNotificationPending;

  static void markJournalNotificationPending() {
    _journalNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static void markDietNotificationPending() {
    _dietNotificationPending = true;
  }

  static bool consumeJournalNotification() {
    final pending = _journalNotificationPending;
    _journalNotificationPending = false;
    launchedFromNotificationPayload = false;
    return pending;
  }

  static Future<void> navigateToJournal({bool fromNotification = false}) async {
    if (fromNotification) {
      markJournalNotificationPending();
    }

    if (isOnJournalPage) {
      if (fromNotification) {
        _journalNotificationPending = false;
        launchedFromNotificationPayload = false;
      }
      return;
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
