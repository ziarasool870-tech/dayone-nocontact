/// Notification permission honesty tests (v7).
///
/// The v6 bug: reminders showed "On" while the OS silently dropped every
/// notification (no POST_NOTIFICATIONS permission, never requested).
/// These tests pin the new contract:
///  1. The profile row summary never claims "On" when blocked.
///  2. scheduleDailyReminder never reports success when the platform
///     cannot schedule (permission denied / plugin unavailable).
library;

import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminderSummaryText', () {
    test('blocked wins over everything — never a fake "On"', () {
      expect(
        reminderSummaryText(
          notificationsOn: true,
          notificationsBlocked: true,
          timeLabel: '8:00 PM',
        ),
        'Off — permission needed',
      );
    });

    test('plain off when the user disabled reminders', () {
      expect(
        reminderSummaryText(
          notificationsOn: false,
          notificationsBlocked: false,
          timeLabel: '8:00 PM',
        ),
        'Off',
      );
    });

    test('on with time only when truly scheduled', () {
      expect(
        reminderSummaryText(
          notificationsOn: true,
          notificationsBlocked: false,
          timeLabel: '8:00 PM',
        ),
        'On · 8:00 PM',
      );
    });

    test('blocked with reminders off still says permission needed', () {
      expect(
        reminderSummaryText(
          notificationsOn: false,
          notificationsBlocked: true,
          timeLabel: '8:00 PM',
        ),
        'Off — permission needed',
      );
    });
  });

  group('NotificationService.scheduleDailyReminder', () {
    test('returns false (never fake success) when the platform is unavailable',
        () async {
      // In flutter_test there is no notification plugin: init() throws
      // MissingPluginException, which the service must convert to a
      // clean false — the same path as a denied permission.
      final ok = await NotificationService.instance.scheduleDailyReminder(
        hour: 20,
        minute: 0,
      );
      expect(ok, isFalse);
    });

    test('notificationsAllowed returns false when the platform is unavailable',
        () async {
      expect(await NotificationService.instance.notificationsAllowed(), isFalse);
    });

    test('requestPermission returns false when the platform is unavailable',
        () async {
      expect(await NotificationService.instance.requestPermission(), isFalse);
    });
  });
}
