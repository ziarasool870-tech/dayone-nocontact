/// QA round-4 regression tests — user-reported device issues (all approved):
/// 1. Journal editor: typed text + hint must be VISIBLE (ink text, faint hint).
/// 2. Date page: quick-pick chips (Today / Yesterday / A week ago) sync with
///    the grid selection; the live preview line updates on tap.
/// 3. SOS pill docks tight above the bottom nav (~4px gap, not floating high).
/// 4. No-overlap: tab scroll views clear the pill zone; no RenderFlex
///    overflow at small size + large text scale.
library;

import 'package:day_one_nocontact/screens/journal_screen.dart';
import 'package:day_one_nocontact/screens/main_shell.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:day_one_nocontact/widgets/premium.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _previewFor(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year} · Day 1 starts here';

/// Test double for Play Billing: the real Android platform implementation
/// (Pigeon) never replies in the test env, so `isAvailable()` would hang
/// (and throws inside runAsync). This fake answers immediately.
class _FakeIapPlatform extends InAppPurchasePlatform
    with MockPlatformInterfaceMixin {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      throw UnimplementedError();

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      throw UnimplementedError();

  @override
  Future<bool> buyConsumable(
          {required PurchaseParam purchaseParam, bool autoConsume = true}) =>
      throw UnimplementedError();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      throw UnimplementedError();

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      throw UnimplementedError();

  @override
  Future<String> countryCode() => throw UnimplementedError();
}

/// Test double for local notifications: the real Android implementation
/// talks to native channels that don't exist in tests.
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
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});

    // Keep the test env hermetic: pin to Linux while the InAppPurchase
    // wrapper is first created so it never registers the real Android
    // platform, then install the immediate-answer fake.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchasePlatform.instance = _FakeIapPlatform();
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    FlutterLocalNotificationsPlatform.instance = _FakeAndroidNotifications();
  });

  group('1. Journal editor visibility', () {
    testWidgets('title + body fields use ink text and faint hint',
        (tester) async {
      await tester.pumpWidget(_wrap(const JournalEditor()));
      await tester.pump();

      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields.length, 2);
      for (final f in fields) {
        expect(f.style?.color, DayOneColors.ink,
            reason: 'typed text must be visible on cream');
        final deco = f.decoration as InputDecoration;
        expect(deco.hintStyle?.color, DayOneColors.faint,
            reason: 'hint must be visible on cream');
      }
    });
  });

  group('2. Date page quick chips + preview', () {
    Future<void> openDatePage(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(OnboardingScreen(onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Continue'));
      await tester.pump(); // flush nested-gesture onTap
      await tester.pump(const Duration(milliseconds: 500)); // page animation
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
    }

    testWidgets('chips render and preview shows today by default',
        (tester) async {
      await openDatePage(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('A week ago'), findsOneWidget);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(find.text(_previewFor(today)), findsOneWidget);
    });

    testWidgets('tapping Yesterday updates the preview line', (tester) async {
      await openDatePage(tester);
      await tester.tap(find.text('Yesterday'));
      await tester.pump();
      final now = DateTime.now();
      final yest = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      expect(find.text(_previewFor(yest)), findsOneWidget);
    });

    testWidgets('tapping A week ago updates the preview line', (tester) async {
      await openDatePage(tester);
      await tester.tap(find.text('A week ago'));
      await tester.pump();
      final now = DateTime.now();
      final weekAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 7));
      expect(find.text(_previewFor(weekAgo)), findsOneWidget);
    });
  });

  group('3. SOS pill docked tight above nav', () {
    testWidgets('pill Positioned bottom is 0 with 4px margin', (tester) async {
      AppState.instance.streakStartMs = DateTime.now().millisecondsSinceEpoch;
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const MainShell()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SosFab), findsOneWidget);
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(SosFab),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.bottom, 0,
          reason: 'pill must sit tight above the bottom nav');
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((container.margin as EdgeInsets).bottom, 4);
    });

    testWidgets('on Journal tab the pill docks left, clear of the FAB',
        (tester) async {
      AppState.instance.streakStartMs = DateTime.now().millisecondsSinceEpoch;
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const MainShell()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Journal'));
      await tester.pump(const Duration(milliseconds: 500));

      final pillRect = tester.getRect(find.descendant(
        of: find.byType(SosFab),
        matching: find.byType(ElevatedButton),
      ));
      final navRect = tester.getRect(find.byType(BottomNavigationBar));
      // Pill button sits ~4px above the nav…
      expect(pillRect.bottom, lessThanOrEqualTo(navRect.top - 2));
      // …and hugs the left side on the Journal tab (FAB lives right).
      expect(pillRect.left, lessThan(120));
    });
  });

  group('4. No-overlap sweep', () {
    testWidgets('no overflow at 320px width + 1.3x text scale on all tabs',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      AppState.instance.streakStartMs = DateTime.now().millisecondsSinceEpoch;
      // runAsync: HomeScreen's initState DB query deadlocks under FakeAsync.
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const MainShell()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 600));

      // Scroll home to the very bottom (pill zone) — must not overflow.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 300));

      for (final tab in ['Journal', 'Milestones']) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 500));
      }
      // flutter_test fails automatically on any RenderFlex overflow.
    });

    testWidgets('tab scroll views keep 140px bottom clearance', (tester) async {
      AppState.instance.streakStartMs = DateTime.now().millisecondsSinceEpoch;
      // runAsync (real async zone): HomeScreen's initState fires a DB
      // query through the sqflite_ffi isolate, which deadlocks under
      // testWidgets' FakeAsync zone and leaves sqflite's watchdog timer
      // pending ("A Timer is still pending" failure).
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const MainShell()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 500));

      // Home tab scroll view.
      final sv = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      expect((sv.padding as EdgeInsets).bottom, greaterThanOrEqualTo(140),
          reason: 'content must clear the floating SOS pill');
    });
  });
}
