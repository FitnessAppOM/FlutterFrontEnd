import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/account_storage.dart';
import '../metrics/daily_journal_service.dart';
import 'navigation_service.dart';
import '../diet/diet_service.dart';

class NotificationService {
  static const int _journalResetHour = 6;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String dailyJournalPayload = 'daily_journal';
  static const String dietPayload = 'diet';

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
    if (Platform.isAndroid) {
      // ignore: avoid_print
      print('[Notif] init() starting for Android');
    }
    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // ignore: avoid_print
        print(
          '[Notif] onDidReceiveNotificationResponse payload=${response.payload}',
        );
        final payload = response.payload;
        _handleNotificationTapPayload(payload);
      },
    );

    if (Platform.isAndroid) {
      await _createAndroidChannel();
    }

    await _requestPermissions();
    // ignore: avoid_print
    print('[Notif] init() complete');
  }

  static Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    const channel = AndroidNotificationChannel(
      _scheduledChannelId,
      _scheduledChannelName,
      description: _scheduledChannelDescription,
      importance: Importance.max,
    );
    await androidPlugin.createNotificationChannel(channel);
    // ignore: avoid_print
    print('[Notif] Android channel "$_scheduledChannelId" created/ensured');
  }

  static Future<void> _setLocalTimeZone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final ianaName = tzInfo.identifier;
      // ignore: avoid_print
      print('[Notif] flutter_timezone IANA=$ianaName');
      final loc = tz.getLocation(ianaName);
      tz.setLocalLocation(loc);
      return;
    } catch (e) {
      // ignore: avoid_print
      print('[Notif] flutter_timezone failed: $e — trying offset fallback');
    }

    final offset = DateTime.now().timeZoneOffset;
    try {
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => tz.TZDateTime.now(loc).timeZoneOffset == offset,
        orElse: () => tz.getLocation('Etc/UTC'),
      );
      tz.setLocalLocation(match);
      // ignore: avoid_print
      print('[Notif] timezone set via offset match: ${match.name}');
      return;
    } catch (_) {}

    tz.setLocalLocation(tz.UTC);
    // ignore: avoid_print
    print('[Notif] timezone fallback to UTC');
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    // ignore: avoid_print
    print('[Notif] Android notification perm result=$androidGranted');

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosSettings = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    // ignore: avoid_print
    print('[Notif] iOS notification perm result=$iosSettings');
  }

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    // ignore: avoid_print
    print('[Notif] schedule id=$id at=$dateTime title=$title');
    final granted = await requestExactAlarmPermission();
    final scheduleMode = granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleDailyJournalReminder() async {
    // ignore: avoid_print
    print('[Notif] scheduleDailyJournalReminder()');
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      await _plugin.cancel(2);
      await _plugin.cancel(3);
      return;
    }
    try {
      final entry = await DailyJournalApi.fetchForDate(
        userId,
        _journalDay(DateTime.now()),
      );
      if (entry != null) {
        await rescheduleDailyJournalRemindersForTomorrow();
        return;
      }
    } catch (_) {
      // If the fetch fails, fall back to scheduling to avoid missing reminders.
    }
    final granted = await requestExactAlarmPermission();
    final scheduleMode = granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.cancel(2);
    await _plugin.cancel(3);
    await _plugin.cancel(4);

    final tz.TZDateTime nextSixAm = _nextInstanceAtHour(6);
    final tz.TZDateTime nextSixPm = _nextInstanceAtHour(18);
    final tz.TZDateTime nextNinePm = _nextInstanceAtHour(21);
    // ignore: avoid_print
    print(
      '[Notif] next 6am=$nextSixAm, next 6pm=$nextSixPm, next 9pm=$nextNinePm, mode=$scheduleMode',
    );

    await _plugin.zonedSchedule(
      2,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixAm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: scheduleMode,
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
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final shouldSendDiet = await _shouldScheduleDietNotification();
    if (shouldSendDiet) {
      await _plugin.zonedSchedule(
        4,
        'Diet check-in',
        'Check your remaining calories. Tap to log your food.',
        nextNinePm,
        _defaultDetails,
        payload: dietPayload,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    await _logPendingNotifications();
  }

  static Future<void> _logPendingNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      // ignore: avoid_print
      print('[Notif] ${pending.length} pending notification(s):');
      for (final p in pending) {
        // ignore: avoid_print
        print('[Notif]   id=${p.id} title=${p.title}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Notif] pendingNotificationRequests error: $e');
    }
  }

  /// Check if today's journal entry exists for the current user and adjust reminders:
  /// - if an entry exists, start reminders again tomorrow (skip the rest of today)
  /// - if no entry exists, ensure today's 6am/6pm reminders are scheduled
  /// - if no user is logged in, clear any pending reminders
  static Future<void> refreshDailyJournalRemindersForCurrentUser() async {
    // ignore: avoid_print
    print('[Notif] refreshDailyJournalRemindersForCurrentUser()');
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      await _plugin.cancel(2);
      await _plugin.cancel(3);
      return;
    }

    try {
      final entry = await DailyJournalApi.fetchForDate(
        userId,
        _journalDay(DateTime.now()),
      );
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
    // ignore: avoid_print
    print('[Notif] rescheduleDailyJournalRemindersForTomorrow()');
    await _plugin.cancel(2);
    await _plugin.cancel(3);
    await _plugin.cancel(4);
    final granted = await requestExactAlarmPermission();
    final scheduleMode = granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // IMPORTANT:
    // Do not use matchDateTimeComponents here. For DateTimeComponents.time,
    // flutter_local_notifications computes the next fire time from "today"
    // using only the clock time, which can still schedule today's 6pm.
    // We want strict "start tomorrow" after journal completion.
    final tz.TZDateTime nextSixAm = _nextInstanceAtHour(6, startTomorrow: true);
    final tz.TZDateTime nextSixPm = _nextInstanceAtHour(
      18,
      startTomorrow: true,
    );
    final tz.TZDateTime nextNinePm = _nextInstanceAtHour(
      21,
      startTomorrow: true,
    );

    await _plugin.zonedSchedule(
      2,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixAm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _plugin.zonedSchedule(
      3,
      'Daily Journal',
      'Please complete your daily journal if you haven\'t already.',
      nextSixPm,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final shouldSendDiet = await _shouldScheduleDietNotification();
    if (shouldSendDiet) {
      await _plugin.zonedSchedule(
        4,
        'Diet check-in',
        'Check your remaining calories. Tap to log your food.',
        nextNinePm,
        _defaultDetails,
        payload: dietPayload,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static tz.TZDateTime _nextInstanceAtHour(
    int hour, {
    bool startTomorrow = false,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime baseDay = startTomorrow
        ? now.add(const Duration(days: 1))
        : now;
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      baseDay.year,
      baseDay.month,
      baseDay.day,
      hour,
    );

    if (!startTomorrow && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceAtTime(
    int hour,
    int minute, {
    bool startTomorrow = false,
  }) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime baseDay = startTomorrow
        ? now.add(const Duration(days: 1))
        : now;
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      baseDay.year,
      baseDay.month,
      baseDay.day,
      hour,
      minute,
    );

    if (!startTomorrow && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid)
      return true; // iOS/macOS: no exact alarm permission

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return true;

    final granted = await androidPlugin.requestExactAlarmsPermission();
    // ignore: avoid_print
    print('[Notif] requestExactAlarmPermission granted=$granted');
    return granted ?? true;
  }

  static Future<void> scheduleTestReminderInTenSeconds() async {
    // ignore: avoid_print
    print('[Notif] scheduleTestReminderInTenSeconds()');
    final granted = await requestExactAlarmPermission();
    final scheduleMode = granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final tz.TZDateTime scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 10));
    // ignore: avoid_print
    print('[Notif] test reminder at $scheduledTime mode=$scheduleMode');

    await _plugin.zonedSchedule(
      999,
      'Daily Journal (Test)',
      'Reminder to fill in your daily journal.',
      scheduledTime,
      _defaultDetails,
      payload: dailyJournalPayload,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Debug helper: schedule a burst of notifications every 10 seconds.
  static Future<void> scheduleDebugNotificationsEveryTenSeconds({
    int count = 3,
  }) async {
    // ignore: avoid_print
    print('[Notif] scheduleDebugNotificationsEveryTenSeconds(count=$count)');
    final granted = await requestExactAlarmPermission();
    final scheduleMode = granted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final shouldSend = await _shouldScheduleDietNotification();
    if (!shouldSend) return;

    final baseId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var i = 0; i < count; i++) {
      final when = tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: 10 * (i + 1)));
      // ignore: avoid_print
      print(
        '[Notif] scheduling debug id=${baseId + i} at=$when mode=$scheduleMode',
      );
      await _plugin.zonedSchedule(
        baseId + i,
        'Diet check-in',
        'Check your remaining calories. Tap to log your food. (${i + 1}/$count)',
        when,
        _defaultDetails,
        payload: dietPayload,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Debug helper: show both journal + diet notifications immediately.
  static Future<void> showDebugJournalAndDietNow() async {
    // ignore: avoid_print
    print('[Notif] showDebugJournalAndDietNow()');
    await _plugin.show(
      910001,
      'Daily Journal (Test)',
      'Tap to open your journal.',
      _defaultDetails,
      payload: dailyJournalPayload,
    );
    await _plugin.show(
      910002,
      'Diet check-in (Test)',
      'Tap to open your diet module.',
      _defaultDetails,
      payload: dietPayload,
    );
  }

  static Future<void> showRemoteMessageNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    if (normalizedTitle.isEmpty && normalizedBody.isEmpty) return;

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      normalizedTitle.isEmpty ? 'New notification' : normalizedTitle,
      normalizedBody,
      _defaultDetails,
      payload: payload,
    );
  }

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static void _handleNotificationTapPayload(String? payload) {
    final raw = (payload ?? '').trim();
    if (raw.isEmpty) return;

    if (raw == dailyJournalPayload) {
      NavigationService.navigateToJournal(fromNotification: true);
      return;
    }
    if (raw == dietPayload) {
      NavigationService.navigateToDiet(fromNotification: true);
      return;
    }

    String? type;
    int? senderUserId;
    String? senderRole;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        type = map['type']?.toString().trim();
        senderUserId = _parseIntOrNull(map['sender_user_id']);
        senderRole = (map['sender_role'] ?? map['senderRole'])
            ?.toString()
            .trim();
      }
    } catch (_) {
      type = raw;
    }

    if (type == 'coach_chat') {
      NavigationService.navigateToChatFromNotification(
        senderUserId: senderUserId,
        senderRole: senderRole,
      );
      return;
    }
    if (type == 'habit_reminder') {
      NavigationService.navigateToCoachFeedback();
      return;
    }
    if (type == 'training_plan_change') {
      NavigationService.navigateToTrain(fromNotification: true);
      return;
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) {
      final raw = v.trim();
      final asInt = int.tryParse(raw);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(raw);
      if (asDouble != null) return asDouble.round();
      return 0;
    }
    return 0;
  }

  static Future<bool> _shouldScheduleDietNotification() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) return true;

    try {
      final summary = await DietService.fetchDaySummary(userId);
      final live = (summary["live"] is Map) ? summary["live"] as Map : summary;
      final remaining = (live["remaining"] is Map)
          ? live["remaining"] as Map
          : const {};
      final dynamic caloriesRaw =
          remaining["calories"] ?? live["remaining_calories"];
      if (caloriesRaw == null) {
        // If the payload shape changes or calories is absent, keep reminder behavior.
        return true;
      }
      final remCal = _toInt(caloriesRaw);
      final shouldSend = remCal > 0;
      // ignore: avoid_print
      print(
        '[Notif] diet reminder gate: remCal=$remCal -> shouldSend=$shouldSend',
      );
      return shouldSend;
    } catch (_) {
      return true;
    }
  }

  static Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  static DateTime _journalDay(DateTime date) {
    final shifted = date.subtract(const Duration(hours: _journalResetHour));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
}
