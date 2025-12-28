import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/account_storage.dart';
import 'daily_journal_service.dart';
import 'navigation_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String dailyJournalPayload = 'daily_journal';

  static const String _scheduledChannelId = 'scheduled_channel';
  static const String _scheduledChannelName = 'Scheduled Notifications';
  static const String _scheduledChannelDescription =
      'Reminders and scheduled notifications.';
  static const NotificationDetails _defaultDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _scheduledChannelId,
      _scheduledChannelName,
      channelDescription: _scheduledChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> init() async {
    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == dailyJournalPayload) {
          NavigationService.navigateToJournal(fromNotification: true);
        }
      },
    );
    await _requestPermissions();
  }

  /// Best-effort local timezone assignment without platform channels.
  /// Tries:
  /// 1) Exact location name match from DateTime.now().timeZoneName
  /// 2) First tz location whose current offset matches the device offset
  /// Falls back to UTC if nothing matches.
  static Future<void> _setLocalTimeZone() async {
    final now = DateTime.now();
    final tzName = now.timeZoneName;
    final offset = now.timeZoneOffset;

    // Attempt exact location name match
    try {
      final loc = tz.getLocation(tzName);
      tz.setLocalLocation(loc);
      return;
    } catch (_) {
      // ignore and continue
    }

    // Attempt offset match
    try {
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => tz.TZDateTime.now(loc).timeZoneOffset == offset,
        orElse: () => tz.getLocation('Etc/UTC'),
      );
      tz.setLocalLocation(match);
      return;
    } catch (_) {
      // ignore and fall back
    }

    tz.setLocalLocation(tz.UTC);
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final granted = await requestExactAlarmPermission();
    if (!granted) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }


  static Future<void> scheduleDailyJournalReminder() async {
    final granted = await requestExactAlarmPermission();
    if (!granted) return;

    await _plugin.cancel(2);
    await _plugin.cancel(3);

    final tz.TZDateTime nextSixAm = _nextInstanceAtHour(6);
    final tz.TZDateTime nextSixPm = _nextInstanceAtHour(18);

    await _plugin.zonedSchedule(
      2,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixAm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      3,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixPm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Check if today's journal entry exists for the current user and adjust reminders:
  /// - if an entry exists, start reminders again tomorrow (skip the rest of today)
  /// - if no entry exists, ensure today's 6am/6pm reminders are scheduled
  /// - if no user is logged in, clear any pending reminders
  static Future<void> refreshDailyJournalRemindersForCurrentUser() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      await _plugin.cancel(2);
      await _plugin.cancel(3);
      return;
    }

    try {
      final entry = await DailyJournalApi.fetchForDate(userId, DateTime.now());
      if (entry != null) {
        await rescheduleDailyJournalRemindersForTomorrow();
        return;
      }
    } catch (_) {
      // If the fetch fails, fall back to scheduling to avoid missing reminders.
    }

    await scheduleDailyJournalReminder();
  }

  static Future<void> rescheduleDailyJournalRemindersForTomorrow() async {
    await _plugin.cancel(2);
    await _plugin.cancel(3);
    final granted = await requestExactAlarmPermission();
    if (!granted) return;

    final tz.TZDateTime nextSixAm = _nextInstanceAtHour(6, startTomorrow: true);
    final tz.TZDateTime nextSixPm = _nextInstanceAtHour(18, startTomorrow: true);

    await _plugin.zonedSchedule(
      2,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixAm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _plugin.zonedSchedule(
      3,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixPm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }


  static tz.TZDateTime _nextInstanceAtHour(int hour, {bool startTomorrow = false}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime baseDay = startTomorrow ? now.add(const Duration(days: 1)) : now;
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, baseDay.year, baseDay.month, baseDay.day, hour);

    if (!startTomorrow && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true; // iOS/macOS: no exact alarm permission

    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return true;

    final granted = await androidPlugin.requestExactAlarmsPermission();
    return granted ?? true;
  }


  static Future<void> scheduleTestReminderInTenSeconds() async {
    final granted = await requestExactAlarmPermission();
    if (!granted) return;

    final tz.TZDateTime scheduledTime =
    tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _plugin.zonedSchedule(
      999,
      'Daily Journal (Test)',
      'Reminder to fill in your daily journal.',
      scheduledTime,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Debug helper: schedule a burst of notifications every 10 seconds.
  static Future<void> scheduleDebugNotificationsEveryTenSeconds({int count = 3}) async {
    final granted = await requestExactAlarmPermission();
    if (!granted) return;

    final baseId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var i = 0; i < count; i++) {
      final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: 10 * (i + 1)));
      await _plugin.zonedSchedule(
        baseId + i,
        'Debug reminder',
        'This is test notification ${i + 1}/$count.',
        when,
        _defaultDetails,
        payload: dailyJournalPayload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }


  static Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }
}
