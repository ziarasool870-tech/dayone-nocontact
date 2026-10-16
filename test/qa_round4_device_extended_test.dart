/// QA round-4 EXTENDED device-behavior audit (device-behavior expert).
/// Extends test/qa_round4_test.dart — does not duplicate its cases.
///
/// Covers:
/// A. Full-tab overflow sweep at 320x568, text scale 1.3x AND 1.5x:
///    every tab scrolled to max, tabs switched (RenderFlex overflow
///    fails automatically in flutter_test).
/// B. Date page at 320px + 1.3x: chips + grid + preview line.
/// C. Journal editor at 320px + keyboard (viewInsets) at 1.3x.
/// D. SOS pill geometry at 320px: vs bottom nav, vs journal FAB,
///    vs tab content at max scroll (140px clearance).
/// E. Dialog audit at 1.3x: reason dialog, relapse sheet,
///    delete-my-data dialog — overflow + white-on-white.
///
/// Test-env notes (same as v5_device_behavior_audit_test.dart):
/// - JournalScreen._reload() queries sqflite through the ffi worker
///   isolate, which deadlocks under flutter_test's FakeAsync zone when
///   issued from initState during pumpWidget. Pumping MainShell inside
///   runAsync (real async zone) lets the initial load complete.
/// - Play Billing's real Android platform never replies here: the fake
///   answers isAvailable() = false immediately.
/// - Lora fonts are loaded so text metrics match a real device.
///
/// These tests change no app code; they exist to PROVE layout behavior.
library;

import 'dart:io';

import 'package:day_one_nocontact/core/content.dart';
import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/data/prefs.dart';
import 'package:day_one_nocontact/screens/journal_screen.dart';
import 'package:day_one_nocontact/screens/main_shell.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/screens/sos_breath_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:day_one_nocontact/widgets/premium.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Loads the bundled Lora fonts so text metrics match a real device.
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

/// Small-screen harness: 320x568 logical px, optional text scale.
void _smallScreen(WidgetTester tester, {double textScale = 1.0}) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
}

void _resetScreen(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.view.resetViewInsets();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
}

/// Pumps MainShell with the journal tab's async DB load completed
/// (runAsync = real async zone; FakeAsync would deadlock the ffi query).
Future<void> _pumpMainShell(WidgetTester tester) async {
  AppState.instance.streakStartMs = DateTime.now().millisecondsSinceEpoch;
  await tester.runAsync(() async {
    await tester.pumpWidget(_wrap(const MainShell()));
    await Future<void>.delayed(const Duration(milliseconds: 800));
  });
  await tester.pump(const Duration(milliseconds: 300));
}

/// Tap a bottom-nav tab by label, scoped to the nav bar so the tab's
/// own AppBar title can't make the finder ambiguous.
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Two pumps after a navigation (push / sheet / dialog): the first frame
/// registers the route, the second builds its page. A single pump leaves
/// the new route unbuilt in tests (on a phone the framework pumps
/// continuously, so this is test-only).
Future<void> _pumpNav(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Drag the visible tab's primary scrollable to its max extent.
/// Targets the scrollable with the largest maxScrollExtent: a TextField's
/// internal Scrollable (e.g. the journal search field) has ~0 extent and
/// must not be grabbed.
Future<void> _scrollToMax(WidgetTester tester) async {
  Finder? target;
  var best = -1.0;
  for (final el in find.byType(Scrollable).evaluate()) {
    final st = (el as StatefulElement).state as ScrollableState;
    if (st.position.maxScrollExtent > best) {
      best = st.position.maxScrollExtent;
      target = find.byElementPredicate((e) => e == el);
    }
  }
  expect(target, isNotNull, reason: 'no scrollable found to drag');
  expect(best, greaterThan(0), reason: 'primary scrollable has no extent');
  // Drag in realistic increments until the position stops advancing, then
  // let any overscroll settle — a single giant drag overshoots in tests.
  double last = -1;
  for (var i = 0; i < 20; i++) {
    await tester.drag(target!, const Offset(0, -800));
    await tester.pump(const Duration(milliseconds: 150));
    final st =
        (target.evaluate().single as StatefulElement).state as ScrollableState;
    final pos = st.position.pixels;
    if ((pos - last).abs() < 0.5) break;
    last = pos;
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Rect _pillRect(WidgetTester tester) => tester.getRect(find.descendant(
      of: find.byType(SosFab),
      matching: find.byType(ElevatedButton),
    ));

/// Seeds 25 journal entries. MUST run inside tester.runAsync(): the
/// sqflite_ffi worker isolate deadlocks under testWidgets' FakeAsync zone.
Future<void> _seedDb(WidgetTester tester) async {
  await tester.runAsync(() async {
    final db = await DayOneDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('journal');
      await txn.delete('checkins');
      await txn.delete('streak_history');
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = txn.batch();
      for (var i = 0; i < 25; i++) {
        batch.insert('journal', {
          'created_ms': now,
          'updated_ms': now,
          'title': 'Entry ${i + 1}: a longer title to stress the layout',
          'body': 'Body ${i + 1}: ${'feeling all the feelings today. ' * 12}',
        });
      }
      await batch.commit(noResult: true);
    });
  });
}

/// Every visible Card must clear the floating SOS pill — the 140px
/// bottom padding on all tab scroll views exists for exactly this.
void _assertPillClearsCards(WidgetTester tester, String tab) {
  final pill = _pillRect(tester);
  final viewport = Rect.fromLTWH(0, 0, 320, 568);
  var checked = 0;
  for (final el in find.byType(Card).evaluate()) {
    final box = el.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (!r.overlaps(viewport)) continue; // offscreen / other tab
    checked++;
    expect(pill.overlaps(r), isFalse,
        reason: '$tab tab: SOS pill $pill overlaps card $r');
  }
  expect(checked, greaterThan(0),
      reason: '$tab tab: expected visible cards to check');
}

/// No Text inside [scope] may resolve to white on a light dialog
/// background — white-on-white is invisible text.
void _assertNoWhiteOnWhite(WidgetTester tester, Finder scope, String label) {
  final texts = find.descendant(of: scope, matching: find.byType(Text));
  expect(texts, findsWidgets, reason: '$label: no Text found in dialog');
  for (final el in texts.evaluate()) {
    final t = el.widget as Text;
    final Color? resolved = t.style?.color ??
        t.textSpan?.style?.color ??
        DefaultTextStyle.of(el).style.color;
    final shown = t.data ?? '[rich text]';
    expect(resolved, isNotNull,
        reason: '$label: "$shown" resolves to no color');
    expect(resolved, isNot(equals(Colors.white)),
        reason: '$label: "$shown" is white-on-white (invisible)');
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();

    // Keep the test env hermetic: pin to Linux while the InAppPurchase
    // wrapper is first created so it never registers the real Android
    // platform, then install the immediate-answer fake.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchasePlatform.instance = _FakeIapPlatform();
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    FlutterLocalNotificationsPlatform.instance = _FakeAndroidNotifications();
  });

  setUp(() async {
    // Prefs cleanup only — DB seeding happens per-test inside runAsync
    // (see _seedDb): sqflite_ffi deadlocks under testWidgets' FakeAsync
    // zone, so all DB work must run in the real async zone.
    final sp = await SharedPreferences.getInstance();
    await sp.remove(PrefsService.kCustomReasons);
    await sp.remove(PrefsService.kHiddenDefaultReasons);
    await sp.remove(PrefsService.kUserName);
  });

  tearDown(() async {
    // Fully close the DB connection so the next test reopens it clean —
    // prevents SQLITE_BUSY from a previous test's in-flight Future.
    await DayOneDatabase.instance.close();
  });

  tearDownAll(() async {
    await DayOneDatabase.instance.wipeAll();
  });

  group('A. overflow sweep 1.3x + 1.5x, every tab at max scroll', () {
    for (final scale in [1.3, 1.5]) {
      testWidgets('no overflow at 320x568, ${scale}x, all tabs max-scrolled',
          (tester) async {
        await _seedDb(tester);
        _smallScreen(tester, textScale: scale);
        addTearDown(() => _resetScreen(tester));
        await _pumpMainShell(tester);
        for (final tab in ['Home', 'Journal', 'Milestones']) {
          await _tapTab(tester, tab);
          await _scrollToMax(tester);
        }
        // Tab switches themselves must not overflow either.
        await _tapTab(tester, 'Home');
        await _scrollToMax(tester);
        // flutter_test fails automatically on any RenderFlex overflow.
      });
    }
  });

  group('B. date page at 320px + 1.3x', () {
    Future<void> openDatePage(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(OnboardingScreen(onFinished: () {})));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Continue'));
      await tester.pump(); // flush nested-gesture onTap
      await tester.pump(const Duration(milliseconds: 500)); // page animation
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
    }

    testWidgets('chips + grid + preview line, no overflow', (tester) async {
      await _seedDb(tester);
      _smallScreen(tester, textScale: 1.3);
      addTearDown(() => _resetScreen(tester));
      await openDatePage(tester);

      // At 1.3x on a 568-tall screen the chips sit below the fold behind
      // the Continue button — scroll them into view first (as a user would).
      final scv = find.byType(SingleChildScrollView);
      for (var i = 0; i < 6; i++) {
        final rect = tester.getRect(find.text('A week ago'));
        if (rect.top >= 0 && rect.bottom <= 460) break;
        await tester.drag(scv, const Offset(0, -250));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 300));

      // 'A week ago' jumps the grid into the previous month — widest layout.
      await tester.tap(find.text('A week ago'));
      await tester.pump(const Duration(milliseconds: 300));
      final now = DateTime.now();
      final weekAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 7));
      expect(find.textContaining('${weekAgo.day} '), findsWidgets,
          reason: 'preview line must show the picked date');

      // Scroll the date page to the bottom — must not overflow.
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 300));

      // Selected chip: white text on terracotta (visible, not washed out).
      final chipText = tester.widget<Text>(find.text('A week ago'));
      expect(chipText.style?.color, equals(Colors.white));
    });
  });

  group('C. journal editor at 320px + keyboard', () {
    testWidgets('title/body fields, no overflow with keyboard open at 1.3x',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester, textScale: 1.3);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => _resetScreen(tester));

      await tester.pumpWidget(_wrap(const JournalEditor()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first,
          'A long title that keeps going and going');
      await tester.enterText(find.byType(TextField).last, 'Body line. ' * 40);
      await tester.pump();

      // Keyboard open + long text: the Column must absorb it, not overflow.
      expect(find.textContaining('A long title'), findsOneWidget);
      expect(find.text('Private · stored only on your phone'), findsOneWidget);
    });
  });

  group('D. SOS pill geometry at 320px', () {
    testWidgets('pill does not overlap the bottom nav (16dp gap)',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester);
      addTearDown(() => _resetScreen(tester));
      await _pumpMainShell(tester);

      final pill = _pillRect(tester);
      final nav = tester.getRect(find.byType(BottomNavigationBar));
      expect(pill.overlaps(nav), isFalse,
          reason: 'SOS pill $pill overlaps bottom nav $nav');
      final gap = nav.top - pill.bottom;
      expect(gap, inInclusiveRange(12, 20),
          reason: 'pill should sit 16dp above the nav, gap was $gap');
    });

    testWidgets('pill clears tab content at max scroll on all 3 tabs',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester);
      addTearDown(() => _resetScreen(tester));
      await _pumpMainShell(tester);
      for (final tab in ['Home', 'Journal', 'Milestones']) {
        await _tapTab(tester, tab);
        await _scrollToMax(tester);
        _assertPillClearsCards(tester, tab);
      }
    });

    testWidgets('journal FAB stays clear of the SOS pill', (tester) async {
      await _seedDb(tester);
      _smallScreen(tester);
      addTearDown(() => _resetScreen(tester));
      await _pumpMainShell(tester);
      await _tapTab(tester, 'Journal');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FloatingActionButton), findsOneWidget,
          reason: 'seeded entries must show the journal FAB');
      final pill = _pillRect(tester);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(pill.overlaps(fab), isFalse,
          reason: 'SOS pill $pill overlaps journal FAB $fab');
    });

    testWidgets('all three tab scroll views keep >=140px bottom padding',
        (tester) async {
      await _seedDb(tester);
      await _pumpMainShell(tester);

      await _tapTab(tester, 'Home');
      final homePad = (tester
              .widget<SingleChildScrollView>(
                  find.byType(SingleChildScrollView).first)
              .padding as EdgeInsets)
          .bottom;
      expect(homePad, greaterThanOrEqualTo(140),
          reason: 'home scroll view must clear the pill zone');

      await _tapTab(tester, 'Milestones');
      final msPad = (tester
              .widget<SingleChildScrollView>(
                  find.byType(SingleChildScrollView).first)
              .padding as EdgeInsets)
          .bottom;
      expect(msPad, greaterThanOrEqualTo(140),
          reason: 'milestones scroll view must clear the pill zone');

      await _tapTab(tester, 'Journal');
      final listPad = (tester
              .widget<ListView>(find.byType(ListView).first)
              .padding as EdgeInsets?)
          ?.bottom;
      expect(listPad, greaterThanOrEqualTo(140),
          reason: 'journal list must clear the pill zone');
    });
  });

  group('E. dialog audit at 320px + 1.3x', () {
    testWidgets('reason dialog: no overflow, no white-on-white',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester, textScale: 1.3);
      addTearDown(() => _resetScreen(tester));
      // Straight to the SOS options screen (the breath screen has its own
      // dedicated overflow test below — the dialog audit isolates the dialog).
      await tester.pumpWidget(_wrap(const SosOptionsScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Read my reasons'), findsOneWidget);
      await tester.tap(find.text('Read my reasons'));
      await _pumpNav(tester);
      await tester.tap(find.text('Add your own reason'));
      await _pumpNav(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      _assertNoWhiteOnWhite(tester, dialog, 'reason dialog');

      // Keyboard open: the scrollable dialog must keep actions reachable.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('relapse sheet: no overflow, no white-on-white',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester, textScale: 1.3);
      addTearDown(() => _resetScreen(tester));
      await _pumpMainShell(tester);
      await tester.scrollUntilVisible(
        find.text('I broke no contact — restart'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('I broke no contact — restart'));
      await _pumpNav(tester);

      expect(find.text('Restart at Day 1'), findsOneWidget);
      final title = tester.widget<Text>(find.text(relapseTitle));
      expect(title.style?.color, equals(DayOneColors.ink),
          reason: 'relapse title must be ink on light sheet');
      final body = tester.widget<Text>(find.text(relapseBody));
      expect(body.style?.color, equals(DayOneColors.muted),
          reason: 'relapse body must be muted on light sheet');
      final keep = tester.widget<Text>(find.text('Keep my streak'));
      expect(keep.style?.color, equals(DayOneColors.muted),
          reason: 'keep-my-streak must be muted on light sheet');
      // 'Restart at Day 1' is white text, but on a terracotta button —
      // verify the effective background is not white. The sheet's button
      // uses the default ElevatedButton style, so resolve it from the theme.
      final btnElement = find
          .ancestor(
            of: find.text('Restart at Day 1'),
            matching: find.byType(ElevatedButton),
          )
          .evaluate()
          .single;
      final bg = ElevatedButtonTheme.of(btnElement)
          .style
          ?.backgroundColor
          ?.resolve({});
      expect(bg, equals(DayOneColors.terracotta),
          reason: 'restart button must be terracotta behind white text');
    });

    testWidgets('delete-my-data dialog: no overflow, no white-on-white',
        (tester) async {
      await _seedDb(tester);
      _smallScreen(tester, textScale: 1.3);
      addTearDown(() => _resetScreen(tester));
      // home_widget has no fake: its unmocked channel never replies in
      // tests, so mock it (the app only reads it best-effort).
      const homeWidget = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidget, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(homeWidget, null);
      });
      await _pumpMainShell(tester);

      // Profile screen via the AppBar avatar.
      await tester.tap(find.byIcon(Icons.person));
      // Profile's stat queries hit the ffi isolate: real async zone.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)));
      await _pumpNav(tester);
      expect(find.text('Profile'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Delete my data'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete my data'));
      await _pumpNav(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      _assertNoWhiteOnWhite(tester, dialog, 'delete-my-data dialog');

      // Destructive action is red-on-card (visible), not white-on-white.
      final del = tester.widget<Text>(find.text('Delete everything'));
      expect(del.style?.color, equals(DayOneColors.sos));
    });
  });

  group('F. SOS breath screen at 320px (crisis screen)', () {
    for (final scale in [1.3, 1.5]) {
      testWidgets('no RenderFlex overflow at 320x568, ${scale}x',
          (tester) async {
        await _seedDb(tester);
        _smallScreen(tester, textScale: scale);
        addTearDown(() => _resetScreen(tester));
        await tester.pumpWidget(_wrap(const SosBreathScreen()));
        await tester.pump(const Duration(milliseconds: 500));
        // The crisis screen must never clip: flutter_test fails on overflow.
        expect(find.text('Breathe with me'), findsOneWidget);
        expect(find.text("I'm okay now"), findsOneWidget);
      });
    }
  });
}
