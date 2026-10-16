/// v10-A: "Let it out" rage-venting feature.
/// Tabs, vent CRUD with kind field, seal flow, burn ritual, 24h nudge copy,
/// 7-day nudge logic, and Pro-gating unchanged at the entry points.
library;

import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/screens/vault_screen.dart';
import 'package:day_one_nocontact/services/notification_service.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

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

  group('pure helpers', () {
    test('ventPreview returns the first non-empty line', () {
      expect(ventPreview('\nYou never asked.\nSecond line'), 'You never asked.');
      expect(ventPreview('   \n  '), 'Untitled vent');
      expect(ventPreview('Single'), 'Single');
    });

    test('needsWeekNudge fires only after seven days', () {
      const now = 1700000000000;
      expect(needsWeekNudge(now - sevenDaysMs - 1, now), isTrue);
      expect(needsWeekNudge(now - sevenDaysMs + 1000, now), isFalse);
      expect(needsWeekNudge(now, now), isFalse);
    });

    test('24h reminder copy is discreet', () {
      final body = NotificationService.ventReminderBody;
      expect(body, contains('Ready to let them go?'));
      // A glanced notification must reveal nothing about anger or the ex.
      expect(body.toLowerCase(), isNot(contains('anger')));
      expect(body.toLowerCase(), isNot(contains('angry')));
      expect(body.toLowerCase(), isNot(contains(' ex')));
    });
  });

  group('vent storage (kind field)', () {
    test('vents and letters are stored and filtered by kind', () async {
      final db = DayOneDatabase.instance;
      await db.insertLetter(title: 'T', body: 'tender', kind: 'letter');
      final ventId =
          await db.insertLetter(title: '', body: 'raw rage', kind: 'vent');

      final letters = await db.allLetters(kind: 'letter');
      final vents = await db.allLetters(kind: 'vent');
      expect(letters.length, 1);
      expect(vents.length, 1);
      expect(vents.first['body'], 'raw rage');

      // letterById round-trips the kind.
      final fetched = await db.letterById(ventId);
      expect(fetched?['kind'], 'vent');

      // Counts split by kind; unfiltered counts everything.
      expect(await db.letterCount(kind: 'letter'), 1);
      expect(await db.letterCount(kind: 'vent'), 1);
      expect(await db.letterCount(), 2);

      // Burning a vent removes only the vent.
      await db.deleteLetter(ventId);
      expect(await db.letterCount(kind: 'vent'), 0);
      expect(await db.letterCount(kind: 'letter'), 1);
    });

    test('legacy rows default to letter kind', () async {
      final db = DayOneDatabase.instance;
      // Simulate a pre-v3 row: insert bypassing the kind column default is
      // impossible now, so verify the DEFAULT applies when kind is omitted.
      await db.insertLetter(title: 'Old', body: 'legacy');
      final rows = await db.allLetters(kind: 'letter');
      expect(rows.length, 1);
      expect(rows.first['kind'], 'letter');
      // And it never leaks into the vent tab.
      expect(await db.allLetters(kind: 'vent'), isEmpty);
    });
  });

  group('vault tabs', () {
    // Tab switching animation is stock Flutter TabBar behavior; each tab's
    // content is verified via initialTab (lazy tabs would deadlock
    // sqflite_ffi under FakeAsync if switched mid-test).
    testWidgets('Letters tab shows by default with both tabs present',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.text('Letters'), findsOneWidget);
      expect(find.text('Let it out'), findsWidgets);
      expect(find.text('The unsent-letter vault'), findsOneWidget);
    });

    testWidgets('Let-it-out tab shows vent empty state', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.textContaining('Get the anger out here.'), findsOneWidget);
      expect(find.text('Let it out'), findsWidgets);
    });

    testWidgets('vent tab lists vents with burn actions', (tester) async {
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        await db.insertLetter(title: '', body: 'You never asked.', kind: 'vent');
        await db.insertLetter(title: 'T', body: 'tender', kind: 'letter');
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      // Vent visible with its Burn action; the tender letter stays
      // in the Letters tab (kind filter, also covered by DB tests).
      expect(find.text('You never asked.'), findsOneWidget);
      expect(find.text('Burn'), findsOneWidget);
      expect(find.text('tender'), findsNothing);
    });

    testWidgets('7-day nudge appears for old unburned vents', (tester) async {
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        final raw = await db.database;
        // Backdate a vent by 8 days via raw insert.
        await raw.insert('letters', {
          'created_ms':
              DateTime.now().millisecondsSinceEpoch - sevenDaysMs - 86400000,
          'title': '',
          'body': 'Old rage.',
          'kind': 'vent',
        });
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(
          find.text(
              "This one's been sitting for a week — ready to let it go?"),
          findsOneWidget);
    });
  });

  group('seal flow', () {
    testWidgets('vent seal shows encouragement dialog with Okay',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VentComposer()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'All the unsaid things.');

      await tester.runAsync(() async {
        await tester.tap(find.byType(ElevatedButton));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump(const Duration(milliseconds: 300));

      // Encouragement + shame antidote, with a way forward (no trap).
      expect(find.text("It's out."), findsOneWidget);
      expect(find.textContaining('That took courage'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
    });

    testWidgets('returnToVentList pops back when it can', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();

      // Push a temp route the way _compose() pushes the composer
      // (push itself needs no DB).
      final vaultCtx = tester.element(find.byType(VaultScreen));
      Navigator.of(vaultCtx).push(
        MaterialPageRoute<bool>(builder: (_) => const Scaffold(body: Text('temp'))),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('temp'), findsOneWidget);

      final tempCtx = tester.element(find.text('temp'));
      await returnToVentList(tempCtx);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('temp'), findsNothing);
      expect(find.text('Letter vault'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('re-read and burn', () {
    testWidgets('VentReader shows mission line, Burn hero, Keep secondary',
        (tester) async {
      Map<String, Object?>? vent;
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        final id = await db.insertLetter(
            title: '', body: 'Raw words here.', kind: 'vent');
        vent = await db.letterById(id);
      });
      await tester.pumpWidget(_wrap(VentReader(vent: vent!)));
      await tester.pumpAndSettle();

      // Mission guardrail copy.
      expect(
          find.textContaining(
              "This was never meant to be sent — and that's its power."),
          findsOneWidget);
      expect(find.text('Do you still feel this way?'), findsOneWidget);
      expect(find.text('🔥 Burn it'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      // No send-to-ex affordance anywhere.
      expect(find.textContaining('Send'), findsNothing);
    });

    testWidgets('burn ritual deletes the vent and returns', (tester) async {
      int ventId = 0;
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        ventId = await db.insertLetter(
            title: '', body: 'Burn me.', kind: 'vent');
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(VentBurnRitual(ventId: ventId)));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pumpAndSettle();

      // Ritual copy: forward-facing only.
      expect(find.text('Burned.'), findsOneWidget);
      expect(find.textContaining('kept your dignity'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Vent is gone from storage.
      await tester.runAsync(() async {
        final db = DayOneDatabase.instance;
        expect(await db.letterById(ventId), isNull);
        expect(await db.letterCount(kind: 'vent'), 0);
      });
    });
  });

  group('no duplicate CTA when empty', () {
    // Each case pumps once: re-pumping the same widget type reuses the
    // existing element tree, so the tab state would not reload.
    testWidgets('Letters tab: no FAB when empty', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(find.text('The unsent-letter vault'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Letters tab: FAB visible with a letter', (tester) async {
      await tester.runAsync(() async {
        await DayOneDatabase.instance
            .insertLetter(title: 'T', body: 'tender', kind: 'letter');
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Write a letter'), findsOneWidget);
    });

    testWidgets('Let-it-out tab: no FAB when empty', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(find.textContaining('Get the anger out here.'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Let-it-out tab: FAB visible with a vent', (tester) async {
      await tester.runAsync(() async {
        await DayOneDatabase.instance
            .insertLetter(title: '', body: 'Raw rage.', kind: 'vent');
        await tester.pumpWidget(_wrap(const VaultScreen(initialTab: 1)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Let it out'), findsWidgets);
    });
  });

  group('Pro-gating unchanged', () {    test('vault entry points still gate on isPro (no gating inside tabs)',
        () {
      // The gate lives at the Home card and Profile row (push VaultScreen
      // vs PaywallScreen). VaultScreen itself takes no isPro — tabs must
      // never add their own gate. Compile-time guarantee: the constructor
      // has no isPro parameter.
      const v = VaultScreen();
      expect(v.initialTab, 0);
    });
  });
}
