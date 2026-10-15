/// Local notifications for Day One: No Contact.
///
/// - Daily check-in reminder at the user's chosen time (default 8:00 PM).
/// - Milestone-unlocked congratulations (fired from the app when detected).
///
/// All local, all free. Warm, non-clinical copy.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'share_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _checkInId = 1001;
  static const _channelId = 'dayone_reminders';
  static const _channelName = 'Gentle reminders';

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Daily check-in reminders and milestone celebrations',
          importance: Importance.defaultImportance,
        ));
    _ready = true;
  }

  /// Schedules (or re-schedules) the daily check-in reminder.
  Future<void> scheduleDailyReminder(
      {required int hour, required int minute}) async {
    await init();
    await _plugin.cancel(_checkInId);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _checkInId,
      'How are you holding up?',
      'One tap: did you hold no contact today? Your streak is cheering for you.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_checkInId);
  }

  /// Immediate congratulations when a milestone unlocks.
  Future<void> notifyMilestone(int day) async {
    await init();
    // Per-milestone copy — Day 7 must never claim "one month".
    final body =
        '${milestoneMessages[day] ?? 'Keep choosing yourself.'} Tap to see your milestone card.';
    await _plugin.show(
      2000 + day,
      'Day $day — you did it!',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
        ),
      ),
    );
  }
}
