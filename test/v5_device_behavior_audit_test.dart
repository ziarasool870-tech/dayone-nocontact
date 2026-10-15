/// Device-behavior audit for Day One v5 — READ-ONLY review tests.
///
/// Pumps the v5-touched UI under tight real-phone constraints
/// (320x568 logical, textScaleFactor 1.0 and 1.3) and fails on any
/// RenderFlex overflow. Run with:
///   flutter test test/v5_device_behavior_audit_test.dart
///
/// These tests change no app code; they exist to PROVE layout behavior.
library;

import 'dart:io';

import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/data/prefs.dart';
import 'package:day_one_nocontact/screens/journal_screen.dart';
import 'package:day_one_nocontact/screens/onboarding_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
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
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

/// Drags the profile SingleChildScrollView until [text] is on screen.
Future<void> _scrollToText(WidgetTester tester, String text) async {
  final scrollable = find.byType(SingleChildScrollView);
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.text(text))) {
      final rect = tester.getRect(find.text(text).first);
      if (rect.top >= 0 && rect.bottom <= 568) return;
    }
    await tester.drag(scrollable.first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(tester.any(find.text(text)), isTrue,
      reason: 'could not scroll to "$text"');
}

/// Test double for Play Billing: the real Android platform implementation
/// (Pigeon) never replies in the test env, so `isAvailable()` would hang.
/// This fake answers immediately.
class _FakeIapPlatform extends InAppPurchasePlatform
    with MockPlatformInterfaceMixin {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
          Set<String> identifiers) =>
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
/// talks to native channels that don't exist in tests. Extending the
/// Android plugin class keeps the plugin's `resolvePlatformSpecific-
/// Implementation` (which uses `!` on Android) happy; every method is a
/// no-op.
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

/// Test double for url_launcher: records the launched URL and returns a
/// configurable result, simulating "no email app installed" with false.
class _MockUrlLauncher extends UrlLauncherPlatform {
  String? launched;
  bool result = true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched = url;
    return result;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  late UrlLauncherPlatform realLauncher;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    realLauncher = UrlLauncherPlatform.instance;

    // Keep the test env hermetic:
    // - Play Billing's real Android platform (Pigeon) never gets a native
    //   reply here: constructing it fires an unhandled async error, and
    //   isAvailable() hangs forever. Briefly pin the target platform to
    //   Linux while the InAppPurchase wrapper is first created so it never
    //   registers the Android platform, then install a fake whose
    //   isAvailable() answers false immediately. (The wrapper is cached,
    //   so no later access re-registers the real platform. The override
    //   is restored before any test runs — flutter_test forbids leaving
    //   foundation debug variables set across tests.)
    // - flutter_local_notifications has no platform registered in tests
    //   (LateError on initialize). Install an Android-shaped no-op fake.
    // These affect only this audit file's process.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchasePlatform.instance = _FakeIapPlatform();
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    FlutterLocalNotificationsPlatform.instance = _FakeAndroidNotifications();
  });

  tearDown(() {
    // Restore the real launcher after mock tests.
    UrlLauncherPlatform.instance = realLauncher;
  });

  setUp(() async {
    // Fresh journal + prefs per test.
    await DayOneDatabase.instance.wipeAll();
    await DayOneDatabase.instance.insertJournal(
        title: 'Morning pages', body: 'Held the line today, quietly.');
    await DayOneDatabase.instance.insertJournal(
        title: 'Healing is slow', body: 'Day 12. The urge passed by noon.');
    await DayOneDatabase.instance.insertJournal(
        title: 'Gym log', body: 'Legs. Did not check their profile.');
    final sp = await SharedPreferences.getInstance();
    await sp.remove(PrefsService.kCustomReasons);
    await sp.remove(PrefsService.kHiddenDefaultReasons);
    await sp.remove(PrefsService.kUserName);
  });

  group('Profile "Your data" section (v5)', () {
    testWidgets('320x568 @1.0: lengthened section — no overflow',
        (tester) async {
      await _pumpSized(tester, const ProfileScreen());
      expect(find.text('Protect your streak'), findsOneWidget);
      await _scrollToText(tester, 'Delete my data');
      _expectNoOverflow(tester, 'profile Your-data section @1.0');
    });

    testWidgets('320x568 @1.3: lengthened section — no overflow',
        (tester) async {
      await _pumpSized(tester, const ProfileScreen(), textScale: 1.3);
      expect(find.text('Protect your streak'), findsOneWidget);
      await _scrollToText(tester, 'Delete my data');
      _expectNoOverflow(tester, 'profile Your-data section @1.3');
    });

    testWidgets('Protect card Row @320/1.3: no overflow', (tester) async {
      await _pumpSized(tester, const ProfileScreen(), textScale: 1.3);
      await _scrollToText(tester, 'Protect your streak');
      _expectNoOverflow(tester, 'protect card Row @1.3');
    });
  });

  group('Delete confirm dialog (v5)', () {
    Future<void> openDialog(WidgetTester tester,
        {double textScale = 1.0}) async {
      await _pumpSized(tester, const ProfileScreen(), textScale: textScale);
      await _scrollToText(tester, 'Delete my data');
      await tester.tap(find.text('Delete my data'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Delete everything?'), findsOneWidget);
    }

    testWidgets('320x568 @1.0: no overflow, buttons reachable',
        (tester) async {
      await openDialog(tester);
      _expectNoOverflow(tester, 'delete dialog @1.0');

      for (final label in ['Keep my data', 'Delete everything']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0),
            reason: '"$label" clipped at top');
        expect(rect.bottom, lessThanOrEqualTo(568),
            reason: '"$label" clipped at bottom');
      }
    });

    testWidgets('320x568 @1.3: no overflow, buttons reachable',
        (tester) async {
      await openDialog(tester, textScale: 1.3);
      _expectNoOverflow(tester, 'delete dialog @1.3');

      for (final label in ['Keep my data', 'Delete everything']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0),
            reason: '"$label" clipped at top @1.3');
        expect(rect.bottom, lessThanOrEqualTo(568),
            reason: '"$label" clipped at bottom @1.3');
        expect(rect.left, greaterThanOrEqualTo(0),
            reason: '"$label" clipped at left @1.3');
        expect(rect.right, lessThanOrEqualTo(320),
            reason: '"$label" clipped at right @1.3');
      }
    });

    testWidgets('dialog contrast is explicit ink-on-card @1.3',
        (tester) async {
      await openDialog(tester, textScale: 1.3);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, DayOneColors.card,
          reason: 'dialog background must be the card color');
      debugPrint('AUDIT: delete dialog scrollable=${dialog.scrollable}');

      final title = tester.widget<Text>(find.text('Delete everything?'));
      expect(title.style?.color, DayOneColors.ink,
          reason: 'dialog title must be explicit ink');

      final content = tester.widget<Text>(find.textContaining(
          'This permanently removes your journal'));
      expect(content.style?.color, DayOneColors.muted,
          reason: 'dialog body must be explicit muted (never white-on-white)');

      _expectNoOverflow(tester, 'delete dialog contrast @1.3');
    });

    testWidgets('"Keep my data" dismisses cleanly @1.3', (tester) async {
      await openDialog(tester, textScale: 1.3);
      await tester.tap(find.text('Keep my data'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Delete everything?'), findsNothing);
      expect(find.text('Delete my data'), findsOneWidget);
      _expectNoOverflow(tester, 'delete dialog dismiss @1.3');
    });

    testWidgets('full delete flow: wipe -> onboarding, no use-after-dispose',
        (tester) async {
      // Native plugins are faked in setUpAll (billing + notifications),
      // so the REAL delete code path (wipe -> prefs -> AppState re-init ->
      // cancel reminder -> reset widget -> pushAndRemoveUntil) runs end
      // to end. home_widget has no fake: its unmocked channel never replies
      // in tests (the app's try/catch only covers real errors), so mock it.
      const homeWidget = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidget, (call) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(homeWidget, null);
      });
      await openDialog(tester, textScale: 1.3);
      await tester.tap(find.text('Delete everything'));
      // Let the dialog's pop transition finish BEFORE the confirm chain's
      // pushAndRemoveUntil runs — otherwise the Navigator juggles a
      // mid-transition pop and a remove-all simultaneously.
      await tester.pump(const Duration(milliseconds: 500));
      // The confirm chain (wipe DB via the ffi isolate, prefs, re-init)
      // needs REAL async time — flutter_test's FakeAsync starves the
      // isolate replies. runAsync lets the chain finish like on a phone.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump(const Duration(milliseconds: 500));

      // The app restarts at onboarding with the whole stack removed.
      // Fixed pumps (not pumpAndSettle): the onboarding screen runs an
      // infinite breathing animation that never settles.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      // The journal rows were really wiped (DB check needs the real
      // async zone after runAsync — see pumpJournal note above).
      await tester.runAsync(() async {
        expect(await DayOneDatabase.instance.journalCount(), 0);
      });
      _expectNoOverflow(tester, 'delete flow -> onboarding @1.3');
    });
  });

  group('mailto "Send feedback" (v5)', () {
    Future<void> tapFeedback(WidgetTester tester) async {
      await _pumpSized(tester, const ProfileScreen());
      await _scrollToText(tester, 'Send feedback');
      await tester.tap(find.text('Send feedback'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tap launches a well-formed mailto: URI', (tester) async {
      final mock = _MockUrlLauncher();
      UrlLauncherPlatform.instance = mock;

      await tapFeedback(tester);

      expect(mock.launched, isNotNull, reason: 'launchUrl was never called');
      final uri = Uri.parse(mock.launched!);
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@dayonenocontact.app');
      expect(uri.queryParameters['subject'], 'Day One feedback');
      _expectNoOverflow(tester, 'mailto tap @1.0');
    });

    testWidgets('no crash path when nothing can handle mailto:',
        (tester) async {
      // Simulates a phone with no email app: the platform returns false
      // (matches url_launcher_android, which catches
      // ActivityNotFoundException and returns false instead of throwing).
      final mock = _MockUrlLauncher()..result = false;
      UrlLauncherPlatform.instance = mock;

      await tapFeedback(tester);

      expect(mock.launched, isNotNull);
      _expectNoOverflow(tester, 'mailto unhandled @1.0');
    });
  });

  group('Journal search (v5)', () {
    /// Pumps the journal screen with entries loaded.
    ///
    /// JournalScreen._reload() queries sqflite through the ffi worker
    /// isolate, which deadlocks under flutter_test's FakeAsync zone when
    /// issued from initState during pumpWidget. Pumping inside runAsync
    /// (real async zone) lets the initial load complete, like on a phone.
    Future<void> pumpJournal(WidgetTester tester,
        {double textScale = 1.0}) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const JournalScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
    }

    testWidgets('320x568 @1.3: search field renders — no overflow',
        (tester) async {
      await pumpJournal(tester, textScale: 1.3);
      expect(find.text('Search your entries…'), findsOneWidget);
      _expectNoOverflow(tester, 'journal search field @1.3');
    });

    testWidgets('search filters entries (case-insensitive)', (tester) async {
      await pumpJournal(tester, textScale: 1.3);
      await tester.enterText(find.byType(TextField), 'HEALING');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Healing is slow'), findsOneWidget);
      expect(find.text('Gym log'), findsNothing);
      _expectNoOverflow(tester, 'journal filtered @1.3');
    });

    testWidgets('"Nothing found" state renders centered @1.3',
        (tester) async {
      await pumpJournal(tester, textScale: 1.3);
      await tester.enterText(find.byType(TextField), 'zzz no such entry');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nothing found'), findsOneWidget);
      // Echoes the query so the user knows what didn't match.
      expect(find.text('No entries mention "zzz no such entry" yet.'),
          findsOneWidget);
      // Centered: a Center ancestor wraps the state column, and the
      // column itself centers its children vertically.
      expect(
        find.ancestor(
            of: find.text('Nothing found'), matching: find.byType(Center)),
        findsWidgets,
      );
      final column = tester.widget<Column>(find
          .ancestor(
              of: find.text('Nothing found'), matching: find.byType(Column))
          .first);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
      _expectNoOverflow(tester, 'journal nothing-found @1.3');
    });

    testWidgets('clear (x) button is tappable and restores the list',
        (tester) async {
      await pumpJournal(tester, textScale: 1.3);
      await tester.enterText(find.byType(TextField), 'gym');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gym log'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump(const Duration(milliseconds: 300));

      // Query cleared: all entries back, clear button gone.
      expect(find.text('Gym log'), findsOneWidget);
      expect(find.text('Healing is slow'), findsOneWidget);
      expect(find.text('Morning pages'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
      _expectNoOverflow(tester, 'journal clear button @1.3');
    });

    testWidgets('simulated keyboard: list resizes, no overflow @1.3',
        (tester) async {
      await pumpJournal(tester, textScale: 1.3);

      // Simulate an open soft keyboard: 300px bottom inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() {
        tester.view.viewInsets = FakeViewPadding.zero;
      });
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 300));

      // The search field stays above the keyboard; the list shrinks
      // (Scaffold default resizeToAvoidBottomInset = true).
      final fieldRect = tester.getRect(find.byType(TextField));
      expect(fieldRect.bottom, lessThanOrEqualTo(568 - 300),
          reason: 'search field hidden behind the keyboard');

      _expectNoOverflow(tester, 'journal with keyboard @1.3');
    });
  });
}
