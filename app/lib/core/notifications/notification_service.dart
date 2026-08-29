import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// Binds [ReminderPlanner] output to the OS scheduler.
///
/// The planning logic lives in [ReminderPlanner] and is unit-tested; this class
/// is the thin, platform-bound half that cannot be tested off a device.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'class_reminders';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Class reminders',
      channelDescription: 'Fires shortly before each of your classes.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialise() async {
    if (_ready) return;
    tz.initializeTimeZones();
    // Dhaka: the routine is a campus timetable, so local wall-clock time is the
    // right frame regardless of where the device thinks it is.
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Ask for permission. Returns false if the user declined.
  Future<bool> requestPermissions() async {
    await initialise();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Replace all pending reminders with [reminders].
  ///
  /// Cancels first so a shrinking schedule cannot leave orphans behind.
  Future<void> reschedule(List<PlannedReminder> reminders) async {
    await initialise();
    await cancelAll();

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        notificationDetails: _details,
        // Exact alarms need a runtime permission on Android 12+. Falling back to
        // inexact keeps reminders working rather than throwing; a class alert a
        // few minutes early is better than none.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    await initialise();
    await _plugin.cancelAll();
  }

  Future<int> pendingCount() async {
    await initialise();
    return (await _plugin.pendingNotificationRequests()).length;
  }
}
