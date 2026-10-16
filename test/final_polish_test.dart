/// Final polish tests (pre-APK): the two user-approved decisions.
/// 1. The decorative "Me/A friend" onboarding question is gone; the setup
///    page keeps its reminder toggle and warm copy, with no dead navigation.
/// 2. Backdating a start date marks already-earned milestones seen SILENTLY:
///    no notification burst, no celebration spam — but they stay unlocked in
///    the milestone gallery.
library;

import 'package:day_one_nocontact/data/prefs.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

/// Records milestone-notification `show` calls instead of firing them.
class _RecordingNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
  final List<int> shownIds = [];

  @override
  Future<bool> initialize(
    AndroidInitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<void> createNotificationChannel(
          AndroidNotificationChannel notificationChannel) async {}

  @override
  Future<void> show(
    int id,
    String? title,
    String? body, {
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shownIds.add(id);
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    AndroidNotificationDetails? notificationDetails, {
    String? payload,
    required AndroidScheduleMode scheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) async {}
}

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pump(); // flush the nested-gesture onTap
  await tester.pump(const Duration(milliseconds: 500)); // page animation
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding: Me/A friend question removed', () {
    testWidgets('setup page has no Me/A friend question, keeps reminders',
        (tester) async {
      await tester.pumpWidget(_wrap(OnboardingScreen(onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 500));

      await _tapContinue(tester); // date page
      await _tapContinue(tester); // setup page

      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      // The decorative question is gone.
      expect(find.text('Who is this\njourney for?'), findsNothing);
      expect(find.text('Me'), findsNothing);
      expect(find.text('A friend'), findsNothing);
      // The useful content stays: reminder toggle + warm headline.
      expect(find.text('A gentle daily\nnudge'), findsOneWidget);
      expect(find.text('Daily check-in reminders'), findsOneWidget);
      expect(find.text('skip for now'), findsOneWidget);
      expect(find.text('Enter Day One'), findsOneWidget);
      // No layout overflow from the restructure.
      expect(tester.takeException(), isNull);
    });

    testWidgets('back chevron still works on the setup page', (tester) async {
      await tester.pumpWidget(_wrap(OnboardingScreen(onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 500));

      await _tapContinue(tester);
      await _tapContinue(tester);
      expect(find.text('STEP 2 OF 2'), findsOneWidget);

      final chevron = find.ancestor(
        of: find.byTooltip('Back'),
        matching: find.byType(IconButton),
      );
      expect(chevron, findsOneWidget);
      await tester.tap(chevron);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
    });
  });

  group('Backdate: milestones marked seen silently', () {
    late _RecordingNotifications recorder;

    setUpAll(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      recorder = _RecordingNotifications();
      FlutterLocalNotificationsPlatform.instance = recorder;
      debugDefaultTargetPlatformOverride = null;
      const homeWidget = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidget, (call) async => null);
    });

    setUp(() async {
      // PrefsService caches its SharedPreferences handle process-wide;
      // clear the live store (not just the mock initial values).
      final sp = await SharedPreferences.getInstance();
      await sp.clear();
      recorder.shownIds.clear();
      AppState.instance.pendingCelebrations.clear();
      AppState.instance.streakStartMs = null;
    });

    test('6-month backdate: no notification burst, no celebrations',
        () async {
      final app = AppState.instance;
      await app.setStartDate(
          DateTime.now().subtract(const Duration(days: 200)));

      // No celebration overlays queued…
      expect(app.pendingCelebrations, isEmpty);
      // …and no milestone notifications fired (ids are 2000 + day).
      expect(
          recorder.shownIds.where((id) => id >= 2000), isEmpty,
          reason: 'backdated milestones must not notify: ${recorder.shownIds}');
      // …but the earned milestones are recorded as seen (gallery unlocks
      // from elapsed days, which is unaffected).
      final prefs = await PrefsService.instance();
      for (final m in [7, 14, 30, 60, 90, 100, 180]) {
        expect(prefs.milestonesSeen, contains(m),
            reason: 'Day $m should be marked seen after backdate');
      }
    });

    test('today start: nothing changes (no milestones earned yet)', () async {
      final app = AppState.instance;
      await app.setStartDate(DateTime.now());

      expect(app.pendingCelebrations, isEmpty);
      expect(recorder.shownIds, isEmpty);
    });
  });
}
