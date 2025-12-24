import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
    // Align tz.local with the device's timezone so 8 AM stays at 8 AM locally.
    try {
      final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

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


  static tz.TZDateTime _nextInstanceAtHour(int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);

    if (scheduledDate.isBefore(now)) {
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
