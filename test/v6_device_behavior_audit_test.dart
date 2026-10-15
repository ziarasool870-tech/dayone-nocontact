/// Device-behavior audit for Day One v6 — READ-ONLY review tests.
///
/// Pumps the v6-touched UI under tight real-phone constraints
/// (320x568 logical, textScaleFactor 1.0 and 1.3) and fails on any
/// RenderFlex overflow. Run with:
///   flutter test test/v6_device_behavior_audit_test.dart
///
/// v6 scope under audit:
///   a. Milestones 100/180/365 — 8 tiles in a 2-column grid.
///   b. Reminder time picker bottom sheet (Profile > Notifications).
///   c. Widget — no UI change; verified by code read only
///      (AppState._pushWidget called from init/setStartDate/relapse,
///      try/catch guarded — see state/app_state.dart).
///   d. Onboarding back chevron rows on date + setup pages.
///
/// These tests change no app code; they exist to PROVE layout behavior.
library;

import 'dart:io';

import 'package:day_one_nocontact/domain/streak.dart' as streak_math;
import 'package:day_one_nocontact/screens/milestones_screen.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

/// Pump [child] at a fixed logical size + text scale, then drain frames.
Future<void> _pumpSized(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(320, 568),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(_wrap(child));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Fails the test if any FlutterError (e.g. RenderFlex overflow) was logged.
void _expectNoOverflow(WidgetTester tester, String label) {
  final err = tester.takeException();
  expect(err, isNull,
      reason: '$label: overflow/layout error under test constraints: $err');
}

/// Loads the bundled Lora fonts so text metrics match a real device.
/// Without this, flutter_test's fallback font renders much wider/taller
/// glyphs and every width-constrained test produces false overflow positives.
Future<void> _loadFonts() async {
  final loader = FontLoader('Lora');
  for (final name in [
    'Lora.ttf', // 400
    'Lora-Medium.ttf', // 500
    'Lora-SemiBold.ttf', // 600
    'Lora-Bold.ttf', // 700
  ]) {
    final bytes = await File('assets/fonts/lora/$name').readAsBytes();
    loader.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await loader.load();
}

/// Drags the first SingleChildScrollView until [text] is on screen.
Future<void> _scrollToText(WidgetTester tester, String text) async {
  final scrollable = find.byType(SingleChildScrollView);
  for (var i = 0; i < 14; i++) {
    if (tester.any(find.text(text))) {
      final rect = tester.getRect(find.text(text).first);
      if (rect.top >= 0 && rect.bottom <= 568) return;
    }
    await tester.drag(scrollable.first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(tester.any(find.text(text)), isTrue,
      reason: 'could not scroll "$text" into view');
}

/// Tap "Continue" once on the onboarding pager.
Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Reset the AppState singleton between tests (it is a process-wide
/// singleton, and ProfileScreen/MilestonesScreen read it directly).
void _resetAppState() {
  final app = AppState.instance;
  app.streakStartMs = null;
  app.longestDays = 0;
  app.totalCleanDays = 0;
  app.userName = '';
  app.notificationsOn = true;
  app.reminderHour = 20;
  app.reminderMinute = 0;
  app.pendingCelebrations.clear();
}

/// Test double for local notifications: the real Android implementation
/// talks to native channels that don't exist in tests (LateError on
/// cancel/initialize). Same pattern as the v5 audit file: extending the
/// Android plugin class keeps resolvePlatformSpecificImplementation happy;
/// every method is a no-op.
class _FakeAndroidNotifications extends AndroidFlutterLocalNotificationsPlugin
    with MockPlatformInterfaceMixin {
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

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    // Hermetic notifications: no native platform in tests.
    FlutterLocalNotificationsPlatform.instance = _FakeAndroidNotifications();
    tzdata.initializeTimeZones();
  });

  setUp(() {
    _resetAppState();
  });

  group('Milestone 8-tile grid (v6)', () {
    testWidgets('320x568 @1.0: no overflow, all 8 tiles present',
        (tester) async {
      await _pumpSized(tester, const MilestonesScreen());
      for (final m in streak_math.milestoneDays) {
        expect(find.text('Day $m'), findsOneWidget,
            reason: 'tile for Day $m missing');
      }
      expect(streak_math.milestoneDays.length, 8,
          reason: 'grid must render 8 tiles (incl. 100/180/365)');
      _expectNoOverflow(tester, 'milestone 8-tile grid @1.0');
    });

    testWidgets('320x568 @1.3: no overflow, all 8 tiles present',
        (tester) async {
      await _pumpSized(tester, const MilestonesScreen(), textScale: 1.3);
      for (final m in streak_math.milestoneDays) {
        expect(find.text('Day $m'), findsOneWidget,
            reason: 'tile for Day $m missing @1.3');
      }
      _expectNoOverflow(tester, 'milestone 8-tile grid @1.3');
    });

    testWidgets('"Day 365" label fits its tile @320/1.3', (tester) async {
      await _pumpSized(tester, const MilestonesScreen(), textScale: 1.3);
      final label = find.text('Day 365');
      expect(label, findsOneWidget);
      final size = tester.getSize(label);
      // Tile width: (320 - 40 padding - 10 spacing) / 2 = 135;
      // tile padding 14/side -> content width 107.
      debugPrint('AUDIT: "Day 365" @320/1.3 = ${size.width}x${size.height}');
      expect(size.width, lessThan(107),
          reason: '"Day 365" overflows the tile content width @1.3');
      expect(size.height, lessThan(40),
          reason: '"Day 365" wrapped to two lines @1.3');
      _expectNoOverflow(tester, 'Day 365 label @1.3');
    });

    testWidgets('widest "N days to go" stays single-line @320/1.3',
        (tester) async {
      // Worst case: Day 365 is the next tile with a 3-digit "to go" count.
      // NOTE: this scenario also unlocks 7 tiles, which exposes BUG-V6-1
      // (unlocked-tile overflow); this test asserts ONLY on the to-go
      // text itself and drains the unrelated overflow, so it stays green
      // while the bug is open. See the KNOWN-BUG group below.
      final startMs = DateTime.now()
          .subtract(const Duration(days: 180))
          .millisecondsSinceEpoch;
      AppState.instance.streakStartMs = startMs;
      expect(streak_math.nextMilestone(AppState.instance.elapsedDays), 365);
      await _pumpSized(tester, const MilestonesScreen(), textScale: 1.3);
      tester.takeException(); // BUG-V6-1, asserted separately below.

      final toGo = find.textContaining(RegExp(r'\d+ days to go'));
      expect(toGo, findsOneWidget);
      debugPrint(
          'AUDIT: to-go text = "${tester.widget<Text>(toGo).data}" @320/1.3 = ${tester.getSize(toGo)}');
      // 10.5px * 1.3 ~= 13.7px; one line is ~20px. Two lines would be ~40.
      expect(tester.getSize(toGo).height, lessThan(28),
          reason: '"N days to go" wrapped to two lines on the Day 365 tile');
    });
  });

  group('Reminder time picker sheet (v6)', () {
    Future<void> openReminderSheet(WidgetTester tester) async {
      await _pumpSized(tester, const ProfileScreen(), textScale: 1.3);
      // Sub-label must show the current reminder time on the row.
      expect(find.text('On · 8:00 PM'), findsOneWidget,
          reason: 'notifications row sub-label must read "On · 8:00 PM"');
      await _scrollToText(tester, 'Notifications');
      await tester.tap(find.text('Notifications'));
      // pumpAndSettle: the sheet's entrance animation must finish or the
      // Switch's hit-test rect lags below the visible sheet.
      await tester.pumpAndSettle();
      expect(find.text('Daily reminders'), findsOneWidget);
    }

    testWidgets('320x568 @1.3: sheet renders, no overflow', (tester) async {
      await openReminderSheet(tester);
      expect(find.text('Reminders'), findsOneWidget); // toggle row
      expect(find.text('Reminder time'), findsOneWidget); // time row
      _expectNoOverflow(tester, 'reminder sheet @1.3');
    });

    testWidgets('320x568 @1.0: sheet renders, no overflow', (tester) async {
      await _pumpSized(tester, const ProfileScreen());
      await _scrollToText(tester, 'Notifications');
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Daily reminders'), findsOneWidget);
      _expectNoOverflow(tester, 'reminder sheet @1.0');
    });

    testWidgets('toggle off/on flips state and UI, sheet stays stable',
        (tester) async {
      await openReminderSheet(tester);
      final toggle = find.byType(Switch);
      expect(toggle, findsOneWidget);

      // Off: state flips AND the Switch widget rebuilds (notifyListeners
      // fires because the faked platform cancel resolves).
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(AppState.instance.notificationsOn, isFalse);
      expect(tester.widget<Switch>(toggle).value, isFalse,
          reason: 'sheet Switch must visually follow the toggled state');
      _expectNoOverflow(tester, 'reminder sheet toggled off @1.3');

      // On again: state + UI restore, time row re-enabled.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(AppState.instance.notificationsOn, isTrue);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(find.text('Reminder time'), findsOneWidget);
      _expectNoOverflow(tester, 'reminder sheet toggled on @1.3');
    });
  });

  group('Onboarding back nav (v6)', () {
    testWidgets('date page @320/1.3: no overflow, chevron present',
        (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await _tapContinue(tester); // -> date page
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      _expectNoOverflow(tester, 'onboarding date page @1.3');
    });

    testWidgets('setup page @320/1.3: no overflow, chevron present',
        (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await _tapContinue(tester); // -> date page
      await _tapContinue(tester); // -> setup page
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      _expectNoOverflow(tester, 'onboarding setup page @1.3');
    });

    testWidgets('date page @320/1.0: no overflow', (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}));
      await _tapContinue(tester); // -> date page
      expect(find.byTooltip('Back'), findsOneWidget);
      _expectNoOverflow(tester, 'onboarding date page @1.0');
    });

    testWidgets('back chevron navigates back and does not overlap STEP label',
        (tester) async {
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await _tapContinue(tester); // -> date page

      final chevron = find.ancestor(
        of: find.byTooltip('Back'),
        matching: find.byType(IconButton),
      );
      expect(chevron, findsOneWidget);
      final chevronRect = tester.getRect(chevron);
      final stepRect = tester.getRect(find.text('STEP 1 OF 2'));
      expect(chevronRect.overlaps(stepRect), isFalse,
          reason: 'back chevron overlaps the STEP label');
      expect(chevronRect.bottom, lessThanOrEqualTo(stepRect.top),
          reason: 'chevron must sit fully above the STEP label');

      // Tapping it goes back to the welcome page.
      await tester.tap(chevron);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('DAY ONE'), findsOneWidget);
      _expectNoOverflow(tester, 'back chevron navigation @1.3');
    });

    testWidgets('BACKROW TAP TARGET: measured size', (tester) async {
      // The _backRow IconButton uses padding: EdgeInsets.zero +
      // constraints: BoxConstraints() (empty). This test measures the
      // REAL tap target to flag sub-48px accessibility concerns.
      await _pumpSized(tester, OnboardingScreen(onFinished: () {}),
          textScale: 1.3);
      await _tapContinue(tester); // -> date page
      final chevron = find.ancestor(
        of: find.byTooltip('Back'),
        matching: find.byType(IconButton),
      );
      final size = tester.getSize(chevron);
      debugPrint('AUDIT: back chevron tap target @320/1.3 = $size');
      // Recorded here as a finding, not a hard fail: the button is
      // reachable (top of a scroll-safe column) but small.
      if (size.width < 48 || size.height < 48) {
        debugPrint(
            'AUDIT-FLAG: back chevron tap target ${size.width}x${size.height} '
            'is under the 48px accessibility minimum.');
      }
      _expectNoOverflow(tester, 'back chevron measurement @1.3');
    });
  });

  group('Milestone domain sanity (v6)', () {
    test('milestoneDays is the 8-tile source of truth', () {
      expect(streak_math.milestoneDays,
          [7, 14, 30, 60, 90, 100, 180, 365]);
    });

    test('next/unlock math covers 100/180/365', () {
      // Display day = elapsed + 1.
      expect(streak_math.nextMilestone(99 - 1), 100);
      expect(streak_math.nextMilestone(178), 180);
      expect(streak_math.nextMilestone(179), 365);
      expect(streak_math.nextMilestone(363), 365);
      expect(streak_math.nextMilestone(364), isNull);
      expect(streak_math.unlockedMilestones(365), containsAll([100, 180, 365]));
    });
  });

  group('KNOWN-BUG regressions (fail until fixed)', () {
    testWidgets('BUG-V6-1 unlocked milestone tiles overflow @320/1.3',
        (tester) async {
      // With ANY unlocked milestone, every unlocked tile's inner Column
      // overflows by 15px at 320x568 @1.3. Contributors (measured):
      //   '★' Text (fontSize 24) -> 47px tall: the glyph is not in Lora,
      //     so it falls back to a font with a huge line box (vs the
      //     locked tile's Icon, a fixed 24px box).
      //   'Unlocked · tap to share' (10.5px) -> 40px: wraps to 2 lines.
      //   'Day N' (17px) -> 33px.
      // Total 47+8+33+4+40 = 132px > 116.7px tile content height.
      // (The first frame after pump can appear clean — the true metrics
      // settle on the next rebuild; a notifyListeners + pump exposes it,
      // which is what a real device shows.)
      // Fix: replace the '★'/'◷' Text glyphs with fixed-size Icons
      // (e.g. Icon(Icons.star_rounded, size: 24)) — that alone saves
      // ~23px and clears the 15px overflow; and/or bound the status
      // Text (maxLines + ellipsis).
      AppState.instance.streakStartMs = DateTime.now()
          .subtract(const Duration(days: 180))
          .millisecondsSinceEpoch;
      await _pumpSized(tester, const MilestonesScreen(), textScale: 1.3);
      AppState.instance.notifyListeners();
      await tester.pump(const Duration(milliseconds: 300));
      // Fails while the bug is present (one overflow per unlocked tile).
      _expectNoOverflow(tester, 'BUG-V6-1 unlocked tiles @320/1.3');
    });
  });
}
