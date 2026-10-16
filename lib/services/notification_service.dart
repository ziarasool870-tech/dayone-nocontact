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

  /// Set by the UI layer (main.dart) so a notification tap can navigate.
  /// Payloads this service emits: `vent:<id>`.
  static void Function(String? payload)? onNotificationTap;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
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

  /// Whether the OS currently allows this app to post notifications.
  /// Never shows a dialog — safe to call at startup or on time changes.
  Future<bool> notificationsAllowed() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Non-Android (or unknown): assume allowed; scheduling is best-effort.
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? true;
    } catch (_) {
      // If we cannot even ask the OS, treat reminders as unavailable
      // rather than faking an "On" state.
      return false;
    }
  }

  /// Requests the notification permission. On Android 13+ this shows the
  /// system dialog, so call only from a user-initiated enable action.
  /// Returns true when notifications may be posted afterwards.
  Future<bool> requestPermission() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules (or re-schedules) the daily check-in reminder.
  ///
  /// User-initiated enable path: asks for the OS permission first (system
  /// dialog on Android 13+). Returns true only when the reminder was
  /// actually scheduled — callers must surface the real state, never a
  /// fake "On".
  Future<bool> scheduleDailyReminder(
      {required int hour, required int minute}) async {
    final granted = await requestPermission();
    if (!granted) return false;
    return _schedule(hour: hour, minute: minute);
  }

  /// Startup / time-change path: never nags with a dialog; schedules only
  /// when the permission is already granted. Returns whether scheduled.
  Future<bool> rescheduleQuietly(
      {required int hour, required int minute}) async {
    if (!await notificationsAllowed()) return false;
    return _schedule(hour: hour, minute: minute);
  }

  Future<bool> _schedule({required int hour, required int minute}) async {
    try {
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
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelDailyReminder() async {
    await init();
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

  // ---------------------------------------------------------- "Let it out"

  /// Discreet 24h re-read nudge body. No mention of anger or the ex —
  /// a glanced notification reveals nothing.
  static const ventReminderBody =
      "Yesterday's words are waiting. Ready to let them go?";

  /// Base for per-vent notification ids (3000 + vent row id).
  static const _ventIdBase = 3000;

  /// "Let it out" 24-hour re-read nudge. Permission-aware: if notifications
  /// are blocked, skips silently (no nag). Tapping opens the vent in
  /// re-read mode via [onNotificationTap].
  Future<bool> scheduleVentReminder({required int ventId}) async {
    if (!await notificationsAllowed()) return false;
    try {
      await init();
      final when = tz.TZDateTime.now(tz.local).add(const Duration(hours: 24));
      await _plugin.zonedSchedule(
        _ventIdBase + ventId,
        'Day One',
        ventReminderBody,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'vent:$ventId',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancels a vent's 24h nudge (e.g. after it is burned early).
  Future<void> cancelVentReminder(int ventId) async {
    try {
      await init();
      await _plugin.cancel(_ventIdBase + ventId);
    } catch (_) {}
  }
}
