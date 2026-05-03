import 'package:flutter/material.dart';
import '../../main/main_layout.dart';
import '../../core/account_storage.dart';
import '../../screens/expert_dashboard_page.dart';
import '../coach/coach_support_chat_service.dart';
import '../../screens/coach_page.dart';
import '../../screens/expert_client_chat_page.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool launchedFromNotificationPayload = false;
  static bool isOnJournalPage = false;
  static bool _journalNotificationPending = false;
  static bool _dietNotificationPending = false;
  static bool _expertAiUpdatesNotificationPending = false;

  static bool get journalNotificationPending => _journalNotificationPending;
  static bool get dietNotificationPending => _dietNotificationPending;
  static bool get expertAiUpdatesNotificationPending =>
      _expertAiUpdatesNotificationPending;

  static void markJournalNotificationPending() {
    _journalNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static void markDietNotificationPending() {
    _dietNotificationPending = true;
  }

  static void markExpertAiUpdatesNotificationPending() {
    _expertAiUpdatesNotificationPending = true;
    launchedFromNotificationPayload = true;
  }

  static bool consumeJournalNotification() {
    final pending = _journalNotificationPending;
    _journalNotificationPending = false;
    launchedFromNotificationPayload = false;
    return pending;
  }

  static bool consumeExpertAiUpdatesNotification() {
    final pending = _expertAiUpdatesNotificationPending;
    _expertAiUpdatesNotificationPending = false;
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

  static Future<void> navigateToTrain({bool fromNotification = false}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)),
      (_) => false,
    );
  }

  static Future<void> navigateToFeed({bool fromNotification = false}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 3)),
      (_) => false,
    );
  }

  static Future<void> navigateToExpertDashboard({
    bool fromNotification = false,
  }) async {
    if (fromNotification) {
      _expertAiUpdatesNotificationPending = false;
      launchedFromNotificationPayload = false;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(builder: (_) => const ExpertDashboardPage()),
    );
  }

  static Future<void> navigateToCoachPage({
    int initialTabIndex = 0,
    int? initialCoachUserId,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => CoachPage(
          initialTabIndex: initialTabIndex,
          initialCoachUserId: initialCoachUserId,
        ),
      ),
    );
  }

  static Future<void> navigateToCoachChat({int? coachUserId}) async {
    await navigateToCoachPage(
      initialTabIndex: 1,
      initialCoachUserId: coachUserId,
    );
  }

  static Future<void> navigateToCoachFeedback() async {
    await navigateToCoachPage(initialTabIndex: 0);
  }

  static Future<void> navigateToChatFromNotification({
    int? senderUserId,
    String? senderRole,
  }) async {
    final normalizedSenderRole = (senderRole ?? '').trim().toLowerCase();
    final isExpert = await AccountStorage.isExpert();
    final senderId = senderUserId ?? 0;
    if (normalizedSenderRole == 'client' && senderId > 0) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ExpertClientChatPage(
            clientUserId: senderId,
            clientName: 'Client',
          ),
        ),
      );
      return;
    }
    if (normalizedSenderRole == 'coach') {
      await navigateToCoachChat(coachUserId: senderId > 0 ? senderId : null);
      return;
    }
    if (isExpert && senderId > 0) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ExpertClientChatPage(
            clientUserId: senderId,
            clientName: 'Client',
          ),
        ),
      );
      return;
    }
    if (!isExpert && senderId > 0) {
      final canOpenAsExpert = await _canOpenExpertThreadForSender(senderId);
      if (canOpenAsExpert) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => ExpertClientChatPage(
              clientUserId: senderId,
              clientName: 'Client',
            ),
          ),
        );
        return;
      }
    }
    await navigateToCoachChat(coachUserId: senderUserId);
  }

  static Future<bool> _canOpenExpertThreadForSender(int senderId) async {
    try {
      await CoachSupportChatService.fetchCoachClientThread(
        clientUserId: senderId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool consumeDietNotification() {
    final pending = _dietNotificationPending;
    _dietNotificationPending = false;
    return pending;
  }
}
