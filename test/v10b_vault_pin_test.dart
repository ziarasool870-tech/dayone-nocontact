/// v10-B: vault PIN lock + "Add widget to Home screen" button.
///
/// Covers: PIN setup/confirm (incl. mismatch), salted-hash storage (never
/// plaintext), gate correct/wrong behavior, session lock rule, forgot-PIN
/// erase, entry-point gating, Pro-gating unchanged, widget pin service.
library;

import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/screens/home_screen.dart';
import 'package:day_one_nocontact/screens/profile_screen.dart';
import 'package:day_one_nocontact/screens/vault_pin_screen.dart';
import 'package:day_one_nocontact/services/vault_pin_service.dart';
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
    await DayOneDatabase.instance.close();
  });

  group('VaultPinService (hash storage)', () {
    test('setPin stores a salted hash — never the raw PIN', () async {
      final storage = MemoryPinStorage();
      VaultPinService.debugReset(storage: storage);
      await VaultPinService.instance.setPin('1234');

      final values = storage.debugValues;
      expect(values['vault_pin_hash'], isNotNull);
      expect(values['vault_pin_salt'], isNotNull);
      // 64 hex chars = SHA-256.
      expect(values['vault_pin_hash']!.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(values['vault_pin_hash']!),
          isTrue);
      // The raw PIN appears nowhere in storage.
      for (final v in values.values) {
        expect(v.contains('1234'), isFalse);
      }
    });

    test('same PIN gets a different hash per install (random salt)',
        () async {
      final a = MemoryPinStorage();
      final b = MemoryPinStorage();
      VaultPinService.debugReset(storage: a);
      await VaultPinService.instance.setPin('1234');
      final hashA = a.debugValues['vault_pin_hash'];

      VaultPinService.debugReset(storage: b);
      await VaultPinService.instance.setPin('1234');
      final hashB = b.debugValues['vault_pin_hash'];

      expect(hashA, isNot(hashB));
      expect(a.debugValues['vault_pin_salt'],
          isNot(b.debugValues['vault_pin_salt']));
    });

    test('verifyPin accepts the right PIN, rejects the wrong one', () async {
      VaultPinService.debugReset();
      expect(await VaultPinService.instance.isEnabled, isFalse);
      expect(await VaultPinService.instance.verifyPin('1234'), isFalse);

      await VaultPinService.instance.setPin('1234');
      expect(await VaultPinService.instance.isEnabled, isTrue);
      expect(await VaultPinService.instance.verifyPin('1234'), isTrue);
      expect(await VaultPinService.instance.verifyPin('0000'), isFalse);
      expect(await VaultPinService.instance.verifyPin(''), isFalse);
    });

    test('clearPin removes hash and salt', () async {
      final storage = MemoryPinStorage();
      VaultPinService.debugReset(storage: storage);
      await VaultPinService.instance.setPin('1234');
      await VaultPinService.instance.clearPin();
      expect(await VaultPinService.instance.isEnabled, isFalse);
      expect(storage.debugValues, isEmpty);
    });

    test('resilient storage falls back to memory when the plugin is missing',
        () async {
      // Simulates a widget test without a mocked secure-storage channel:
      // MissingPluginException → in-memory fallback, no crash.
      final throwing = _ThrowingStorage();
      final resilient = ResilientPinStorage(throwing);
      VaultPinService.debugReset(storage: resilient);
      expect(await VaultPinService.instance.isEnabled, isFalse);
      await VaultPinService.instance.setPin('1234');
      expect(await VaultPinService.instance.isEnabled, isTrue);
      expect(await VaultPinService.instance.verifyPin('1234'), isTrue);
    });
  });

  group('session lock rule', () {    test('cold start is locked; unlock persists until lock()', () async {
      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');
      // Setup unlocks the session...
      expect(VaultPinService.instance.isUnlocked, isTrue);
      // ...backgrounding re-locks it.
      VaultPinService.instance.lock();
      expect(VaultPinService.instance.isUnlocked, isFalse);
      // A fresh singleton (cold start) always starts locked.
      VaultPinService.debugReset();
      expect(VaultPinService.instance.isUnlocked, isFalse);
    });
  });

  group('setup screen', () {
    testWidgets('matching PINs complete setup with success view',
        (tester) async {
      VaultPinService.debugReset();
      await tester.pumpWidget(_wrap(const VaultPinSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      await _enterPin(tester, '1234');
      expect(find.text('Confirm your PIN'), findsOneWidget);
      await _enterPin(tester, '1234');

      expect(find.text('Your vault is locked.'), findsOneWidget);
      expect(await VaultPinService.instance.isEnabled, isTrue);
      expect(await VaultPinService.instance.verifyPin('1234'), isTrue);
    });

    testWidgets('mismatched PINs show a gentle error and restart',
        (tester) async {
      VaultPinService.debugReset();
      await tester.pumpWidget(_wrap(const VaultPinSetupScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      await _enterPin(tester, '1234');
      await _enterPin(tester, '0000');

      expect(find.text("Those PINs don't match — try again."),
          findsOneWidget);
      expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
      expect(await VaultPinService.instance.isEnabled, isFalse);
    });
  });

  group('gate screen', () {
    testWidgets('wrong PIN shows error; correct PIN pops true',
        (tester) async {
      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');
      VaultPinService.instance.lock();

      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                      builder: (_) => const VaultPinGateScreen()),
                );
              },
              child: const Text('open gate'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);

      await _enterPin(tester, '0000');
      expect(find.text("That wasn't it — try again."), findsOneWidget);
      expect(find.text('Enter your PIN'), findsOneWidget);

      await _enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(VaultPinService.instance.isUnlocked, isTrue);
    });

    testWidgets('Forgot PIN link opens the erase screen', (tester) async {
      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');
      VaultPinService.instance.lock();

      await tester.pumpWidget(_wrap(const VaultPinGateScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();
      expect(find.text("There's no way to get your PIN back."),
          findsOneWidget);
    });
  });

  group('forgot-PIN erase', () {
    testWidgets('typing ERASE wipes letters, vents and the PIN',
        (tester) async {
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        await db.insertLetter(
            title: 't', body: 'tender letter', kind: 'letter');
        await db.insertLetter(title: 'v', body: 'raw vent', kind: 'vent');
        expect(await db.letterCount(), 2);
      });

      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');

      await tester.pumpWidget(_wrap(const VaultPinForgotScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Button is disabled until ERASE is typed.
      final eraseButton =
          find.widgetWithText(FilledButton, 'Erase vault and start fresh');
      await tester.tap(eraseButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        expect(await DayOneDatabase.instance.letterCount(), 2);
      });

      await tester.enterText(find.byType(TextField), 'ERASE');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(eraseButton);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        expect(await DayOneDatabase.instance.letterCount(), 0);
      });
      expect(await VaultPinService.instance.isEnabled, isFalse);
    });
  });

  group('entry-point gating (ensureVaultUnlocked)', () {
    testWidgets('no PIN: Pro user goes straight to the vault',
        (tester) async {
      VaultPinService.debugReset();
      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ensureVaultUnlocked(
                context,
                isPro: true,
                vault: const Text('VAULT_MARKER'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('VAULT_MARKER'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsNothing);
    });

    testWidgets('PIN set + locked: gate appears before the vault',
        (tester) async {
      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');
      VaultPinService.instance.lock();

      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ensureVaultUnlocked(
                context,
                isPro: true,
                vault: const Text('VAULT_MARKER'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.text('VAULT_MARKER'), findsNothing);

      // Correct PIN → vault opens.
      await _enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text('VAULT_MARKER'), findsOneWidget);
    });

    testWidgets('PIN set + unlocked session: no gate', (tester) async {
      VaultPinService.debugReset();
      await VaultPinService.instance.setPin('1234');
      // setPin unlocks the session (foreground).

      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ensureVaultUnlocked(
                context,
                isPro: true,
                vault: const Text('VAULT_MARKER'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('VAULT_MARKER'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsNothing);
    });

    testWidgets('free user still gets the paywall (Pro-gating unchanged)',
        (tester) async {
      VaultPinService.debugReset();
      await tester.pumpWidget(MaterialApp(
        theme: DayOneTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ensureVaultUnlocked(
                context,
                isPro: false,
                vault: const Text('VAULT_MARKER'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Day One Pro'), findsOneWidget);
      expect(find.text('VAULT_MARKER'), findsNothing);
    });
  });

  group('VaultPinRow (Profile)', () {
    testWidgets('shows Off when no PIN, Locked after setup', (tester) async {
      VaultPinService.debugReset();
      await tester.pumpWidget(_wrap(const VaultPinRow(key: ValueKey('a'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Vault PIN'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);

      await VaultPinService.instance.setPin('1234');
      // Fresh key → fresh state → re-reads the PIN status (same as the
      // real row's _refresh() after returning from setup/manage).
      await tester.pumpWidget(_wrap(const VaultPinRow(key: ValueKey('b'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Locked'), findsOneWidget);
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
      // Mock the home_widget channel so the real service call succeeds.
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

      VaultPinService.debugReset();
      await tester.pumpWidget(_wrap(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 600));

      final themeRow = find.text('Widget theme');
      await tester.scrollUntilVisible(themeRow, 400);
      await tester.tap(themeRow);
      await tester.pumpAndSettle();

      expect(find.text('Add widget to Home screen'), findsOneWidget);
      expect(find.text('One tap — your phone will ask where to place it.'),
          findsOneWidget);

      // Tap → system pin request fires, sheet closes (no fallback dialog).
      final pinButton =
          find.widgetWithText(FilledButton, 'Add widget to Home screen');
      expect(pinButton, findsOneWidget);
      // The sheet has its own scrollable (Profile has another) — drag the
      // sheet's explicitly instead of scrollUntilVisible's default.
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

      VaultPinService.debugReset();
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
      // Tight width: 320dp — the smallest we support.
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed a live streak so the check-in card (with the mood row) renders.
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
      // Any RenderFlex overflow would have failed the test above.
    });
  });
}
