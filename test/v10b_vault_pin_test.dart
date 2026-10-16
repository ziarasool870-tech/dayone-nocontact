/// v10-B: App lock (app-wide optional PIN, default OFF) + recovery code.
///
/// Covers: PIN setup/confirm (incl. mismatch), recovery-code generation +
/// one-time save gate, salted-hash storage (never plaintext), gate
/// correct/wrong behavior, session lock rule, maybeShowAppLockGate,
/// recovery flow with code rotation, both-lost honesty (no wipe),
/// AppLockRow On/Off, widget pin button, mood labels.
library;

import 'dart:async';

import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/screens/app_lock_screen.dart';
import 'package:day_one_nocontact/screens/home_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/services/app_lock_service.dart';
import 'package:day_one_nocontact/services/widget_pin_service.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

/// Taps the PIN pad digits in order, then lets the 120ms completion fire.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch));
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// Storage that always throws MissingPluginException — simulates a widget
/// test running without a mocked secure-storage platform channel.
class _ThrowingStorage implements PinStorage {
  MissingPluginException get _e =>
      MissingPluginException('No implementation found');

  @override
  Future<String?> read(String key) async => throw _e;

  @override
  Future<void> write(String key, String value) async => throw _e;

  @override
  Future<void> delete(String key) async => throw _e;

  @override
  Future<void> deleteAll() async => throw _e;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    final db = await DayOneDatabase.instance.database;
    await db.delete('letters');
    await db.delete('journal');
    await DayOneDatabase.instance.close();
    debugResetAppLockGate();
  });

  group('AppLockService (hash storage)', () {
    test('setPin stores a salted hash — never the raw PIN', () async {
      final storage = MemoryPinStorage();
      AppLockService.debugReset(storage: storage);
      await AppLockService.instance.setPin('1234');

      final values = storage.debugValues;
      expect(values['vault_pin_hash'], isNotNull);
      expect(values['vault_pin_salt'], isNotNull);
      expect(values['vault_pin_hash']!.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(values['vault_pin_hash']!),
          isTrue);
      for (final v in values.values) {
        expect(v.contains('1234'), isFalse);
      }
    });

    test('same PIN gets a different hash per install (random salt)',
        () async {
      final a = MemoryPinStorage();
      final b = MemoryPinStorage();
      AppLockService.debugReset(storage: a);
      await AppLockService.instance.setPin('1234');
      final hashA = a.debugValues['vault_pin_hash'];

      AppLockService.debugReset(storage: b);
      await AppLockService.instance.setPin('1234');
      final hashB = b.debugValues['vault_pin_hash'];

      expect(hashA, isNot(hashB));
    });

    test('verifyPin accepts the right PIN, rejects the wrong one', () async {
      AppLockService.debugReset();
      expect(await AppLockService.instance.isEnabled, isFalse);
      expect(await AppLockService.instance.verifyPin('1234'), isFalse);

      await AppLockService.instance.setPin('1234');
      expect(await AppLockService.instance.isEnabled, isTrue);
      expect(await AppLockService.instance.verifyPin('1234'), isTrue);
      expect(await AppLockService.instance.verifyPin('0000'), isFalse);
    });

    test('clearAll removes PIN and recovery code', () async {
      final storage = MemoryPinStorage();
      AppLockService.debugReset(storage: storage);
      await AppLockService.instance.setPin('1234');
      await AppLockService.instance.setRecoveryCode('ABCD-EFGH-JKLM');
      await AppLockService.instance.clearAll();
      expect(await AppLockService.instance.isEnabled, isFalse);
      expect(await AppLockService.instance.hasRecoveryCode, isFalse);
      expect(storage.debugValues, isEmpty);
    });

    test('resilient storage falls back to memory when the plugin is missing',
        () async {
      final resilient = ResilientPinStorage(_ThrowingStorage());
      AppLockService.debugReset(storage: resilient);
      expect(await AppLockService.instance.isEnabled, isFalse);
      await AppLockService.instance.setPin('1234');
      expect(await AppLockService.instance.isEnabled, isTrue);
      expect(await AppLockService.instance.verifyPin('1234'), isTrue);
    });
  });

  group('recovery code', () {
    test('format is XXXX-XXXX-XXXX with unambiguous chars', () {
      for (var i = 0; i < 50; i++) {
        final code = AppLockService.generateRecoveryCode();
        expect(
            RegExp(r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$')
                .hasMatch(code),
            isTrue,
            reason: 'bad code: $code');
      }
      // Uniqueness sanity: 50 codes, all different.
      final codes = List.generate(
          50, (_) => AppLockService.generateRecoveryCode());
      expect(codes.toSet().length, 50);
    });

    test('stored as salted hash — never the plaintext', () async {
      final storage = MemoryPinStorage();
      AppLockService.debugReset(storage: storage);
      const code = 'ABCD-EFGH-JKLM';
      await AppLockService.instance.setRecoveryCode(code);

      expect(await AppLockService.instance.hasRecoveryCode, isTrue);
      final values = storage.debugValues;
      expect(values['app_lock_recovery_hash'], isNotNull);
      expect(values['app_lock_recovery_hash']!.length, 64);
      for (final v in values.values) {
        expect(v.contains('ABCD'), isFalse);
        expect(v.contains('EFGH'), isFalse);
      }
    });

    test('verify accepts the code, forgiving of case/dashes', () async {
      AppLockService.debugReset();
      await AppLockService.instance.setRecoveryCode('ABCD-EFGH-JKLM');
      expect(
          await AppLockService.instance.verifyRecoveryCode('ABCD-EFGH-JKLM'),
          isTrue);
      expect(
          await AppLockService.instance.verifyRecoveryCode('abcd-efgh-jklm'),
          isTrue);
      expect(
          await AppLockService.instance.verifyRecoveryCode('ABCDEFGHJKLM'),
          isTrue);
      expect(
          await AppLockService.instance.verifyRecoveryCode('ZZZZ-ZZZZ-ZZZZ'),
          isFalse);
    });

    test('setting a new code invalidates the old one (rotation)', () async {
      AppLockService.debugReset();
      await AppLockService.instance.setRecoveryCode('ABCD-EFGH-JKLM');
      await AppLockService.instance.setRecoveryCode('NPQR-STUV-WXYZ');
      expect(
          await AppLockService.instance.verifyRecoveryCode('ABCD-EFGH-JKLM'),
          isFalse);
      expect(
          await AppLockService.instance.verifyRecoveryCode('NPQR-STUV-WXYZ'),
          isTrue);
    });
  });

  group('session lock rule', () {
    test('cold start is locked; unlock persists until lock()', () async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      expect(AppLockService.instance.isUnlocked, isTrue);
      AppLockService.instance.lock();
      expect(AppLockService.instance.isUnlocked, isFalse);
      AppLockService.debugReset();
      expect(AppLockService.instance.isUnlocked, isFalse);
    });

    test('default is OFF — no PIN, no code, no lock', () async {
      AppLockService.debugReset();
      expect(await AppLockService.instance.isEnabled, isFalse);
      expect(await AppLockService.instance.hasRecoveryCode, isFalse);
    });
  });

  group('setup screen', () {
    testWidgets(
        'matching PINs → recovery code shown; nothing stored until '
        '"I\'ve saved it"', (tester) async {
      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const AppLockSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      await _enterPin(tester, '1234');
      expect(find.text('Confirm your PIN'), findsOneWidget);
      await _enterPin(tester, '1234');

      // Recovery code screen — shown exactly once.
      expect(find.text('Save this code'), findsOneWidget);
      final codeFinder = find.textContaining(RegExp(
          r'[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}'));
      expect(codeFinder, findsOneWidget);
      // Nothing persisted yet — setup cannot finish without confirmation.
      expect(await AppLockService.instance.isEnabled, isFalse);
      expect(await AppLockService.instance.hasRecoveryCode, isFalse);

      await tester.tap(find.text('I\u2019ve saved it'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Your app is locked.'), findsOneWidget);
      expect(await AppLockService.instance.isEnabled, isTrue);
      expect(await AppLockService.instance.verifyPin('1234'), isTrue);
      expect(await AppLockService.instance.hasRecoveryCode, isTrue);
    });

    testWidgets('mismatched PINs show a gentle error and restart',
        (tester) async {
      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const AppLockSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      await _enterPin(tester, '1234');
      await _enterPin(tester, '0000');

      expect(find.text("Those PINs don't match — try again."),
          findsOneWidget);
      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      expect(await AppLockService.instance.isEnabled, isFalse);
    });
  });

  group('gate screen', () {
    testWidgets('wrong PIN shows error; correct PIN calls onUnlocked',
        (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      AppLockService.instance.lock();

      var unlocked = false;
      await tester.pumpWidget(_wrap(AppLockGateScreen(
        onUnlocked: () => unlocked = true,
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Enter your PIN'), findsOneWidget);

      await _enterPin(tester, '0000');
      expect(find.text("That wasn't it — try again."), findsOneWidget);
      expect(unlocked, isFalse);

      await _enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 300));
      expect(unlocked, isTrue);
      expect(AppLockService.instance.isUnlocked, isTrue);
    });

    testWidgets('pushed gate pops true on correct PIN', (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      AppLockService.instance.lock();

      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => const AppLockGateScreen()),
                );
              },
              child: const Text('open gate'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();
      await _enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Forgot PIN? opens the recovery screen', (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      AppLockService.instance.lock();

      await tester.pumpWidget(_wrap(const AppLockGateScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your recovery code'), findsOneWidget);
    });
  });

  group('recovery flow', () {
    testWidgets('wrong code is rejected gently', (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      await AppLockService.instance.setRecoveryCode('ABCD-EFGH-JKLM');

      await tester.pumpWidget(_wrap(const AppLockRecoverScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'ZZZZ-ZZZZ-ZZZZ');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("That code doesn't match — try again."),
          findsOneWidget);
    });

    testWidgets('correct code → new PIN → new code shown; old code dead',
        (tester) async {
      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const AppLockSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await _enterPin(tester, '1234');
      await _enterPin(tester, '1234');
      final oldCode = (tester.widget<Text>(find.textContaining(RegExp(
              r'[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}')))
          .data)!;
      await tester.tap(find.text('I\u2019ve saved it'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Your app is locked.'), findsOneWidget);
      // (Skipping the Done tap: in this test setup is the root route, and
      // popping it would break the test navigator. The real app pushes it.)

      // Recover with the code (fresh tree, as if returning later).
      await tester.pumpWidget(_wrap(const AppLockRecoverScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), oldCode);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      // New PIN flow.
      expect(find.text('Choose a new 4-digit PIN'), findsOneWidget);
      await _enterPin(tester, '9999');
      await _enterPin(tester, '9999');

      // A NEW code is shown and must be saved again.
      expect(find.text('Save this code'), findsOneWidget);
      final newCode = (tester.widget<Text>(find.textContaining(RegExp(
              r'[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}')))
          .data)!;
      expect(newCode, isNot(oldCode));
      await tester.tap(find.text('I\u2019ve saved it'));
      await tester.pump(const Duration(milliseconds: 500));

      // Old code dead, new code alive, new PIN works.
      expect(
          await AppLockService.instance.verifyRecoveryCode(oldCode),
          isFalse);
      expect(
          await AppLockService.instance.verifyRecoveryCode(newCode),
          isTrue);
      expect(await AppLockService.instance.verifyPin('9999'), isTrue);
      expect(await AppLockService.instance.verifyPin('1234'), isFalse);
    });

    testWidgets('both lost → honest screen, nothing is wiped',
        (tester) async {
      await tester.runAsync(() async {
        await DayOneDatabase.instance
            .insertLetter(title: 't', body: 'b', kind: 'letter');
        expect(await DayOneDatabase.instance.letterCount(), 1);
      });
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      await AppLockService.instance.setRecoveryCode('ABCD-EFGH-JKLM');

      await tester.pumpWidget(_wrap(const AppLockRecoverScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('I don\u2019t have my code either'));
      await tester.pumpAndSettle();

      expect(find.text('Your words stay locked.'), findsOneWidget);
      expect(find.textContaining('even we can\u2019t open them'),
          findsOneWidget);
      // No wipe anywhere: letters and PIN survive.
      await tester.runAsync(() async {
        expect(await DayOneDatabase.instance.letterCount(), 1);
      });
      expect(await AppLockService.instance.isEnabled, isTrue);
    });
  });

  group('maybeShowAppLockGate', () {
    testWidgets('no gate when App lock is OFF', (tester) async {
      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const Scaffold(
        body: Text('HOME'),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      final ctx = tester.element(find.text('HOME'));
      await maybeShowAppLockGate(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsNothing);
    });

    testWidgets('no gate when the session is already unlocked',
        (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234'); // unlocks session
      await tester.pumpWidget(_wrap(const Scaffold(
        body: Text('HOME'),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      final ctx = tester.element(find.text('HOME'));
      await maybeShowAppLockGate(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsNothing);
    });

    testWidgets('gate appears when locked; correct PIN dismisses it',
        (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      AppLockService.instance.lock();

      await tester.pumpWidget(_wrap(const Scaffold(
        body: Text('HOME'),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      final ctx = tester.element(find.text('HOME'));
      // Don't await: the future completes only when the gate pops.
      unawaited(maybeShowAppLockGate(ctx));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);

      await _enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('never stacks two gates', (tester) async {
      AppLockService.debugReset();
      await AppLockService.instance.setPin('1234');
      AppLockService.instance.lock();

      await tester.pumpWidget(_wrap(const Scaffold(
        body: Text('HOME'),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      final ctx = tester.element(find.text('HOME'));
      unawaited(maybeShowAppLockGate(ctx));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);
      // Second call while the gate is up: guard stops a duplicate.
      unawaited(maybeShowAppLockGate(ctx));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);
    });
  });

  group('AppLockRow (Profile)', () {
    testWidgets('shows Off when no lock, On after setup', (tester) async {
      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const AppLockRow(key: ValueKey('a'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('App lock'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);

      await AppLockService.instance.setPin('1234');
      await tester.pumpWidget(_wrap(const AppLockRow(key: ValueKey('b'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('On'), findsOneWidget);
    });
  });

  group('WidgetPinService', () {
    test('returns true when supported and the call succeeds', () async {
      final svc = WidgetPinService(
        supportCheck: () async => true,
        requestCall: () async {},
      );
      expect(await svc.requestPin(), isTrue);
    });

    test('returns false when pinning is not supported', () async {
      var called = false;
      final svc = WidgetPinService(
        supportCheck: () async => false,
        requestCall: () async {
          called = true;
        },
      );
      expect(await svc.requestPin(), isFalse);
      expect(called, isFalse);
    });

    test('returns false when the platform call throws', () async {
      final svc = WidgetPinService(
        supportCheck: () async => true,
        requestCall: () async {
          throw PlatformException(code: 'nope');
        },
      );
      expect(await svc.requestPin(), isFalse);
    });
  });

  group('widget theme sheet pin button', () {
    testWidgets('sheet has the pin button with the approved copy',
        (tester) async {
      const channel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isRequestPinWidgetSupported') return true;
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 600));

      final themeRow = find.text('Widget theme');
      await tester.scrollUntilVisible(themeRow, 400);
      await tester.tap(themeRow);
      await tester.pumpAndSettle();

      expect(find.text('Add widget to Home screen'), findsOneWidget);
      expect(find.text('One tap — your phone will ask where to place it.'),
          findsOneWidget);

      final pinButton =
          find.widgetWithText(FilledButton, 'Add widget to Home screen');
      expect(pinButton, findsOneWidget);
      final sheetScrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      await tester.drag(sheetScrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(pinButton);
      await tester.pumpAndSettle();
      expect(find.text('Add widget to Home screen'), findsNothing);
      expect(find.text('Add the widget yourself'), findsNothing);
    });

    testWidgets('unsupported launcher shows the manual-steps dialog',
        (tester) async {
      const channel = MethodChannel('home_widget');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isRequestPinWidgetSupported') return false;
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      AppLockService.debugReset();
      await tester.pumpWidget(_wrap(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 600));

      final themeRow = find.text('Widget theme');
      await tester.scrollUntilVisible(themeRow, 400);
      await tester.tap(themeRow);
      await tester.pumpAndSettle();

      final pinButton =
          find.widgetWithText(FilledButton, 'Add widget to Home screen');
      final sheetScrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      await tester.drag(sheetScrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(pinButton);
      await tester.pumpAndSettle();
      expect(find.text('Add the widget yourself'), findsOneWidget);
      expect(find.textContaining('Pinch in on your Home screen'),
          findsOneWidget);
    });
  });

  group('mood row labels (v10-B)', () {
    testWidgets('labels render at 11.5px with no overflow on a narrow phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AppState.instance.streakStartMs =
          DateTime.now().millisecondsSinceEpoch;

      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(find.text('Mood right now'), 400);
      for (final label in ['Rough', 'Low', 'Okay', 'Good', 'Great']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        final text = tester.widget<Text>(finder);
        expect(text.style?.fontSize, 11.5);
      }
    });
  });
}
