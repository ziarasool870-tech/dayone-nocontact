/// v8: 90-day guided program + letter vault.
library;

import 'package:day_one_nocontact/core/program_tasks.dart';
import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/data/prefs.dart';
import 'package:day_one_nocontact/domain/streak.dart' as streak_math;
import 'package:day_one_nocontact/screens/program_screen.dart';
import 'package:day_one_nocontact/screens/vault_screen.dart';
import 'package:day_one_nocontact/state/app_state.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

/// Mirrors the unlock rule used by ProgramScreen: Day N unlocks when the
/// no-contact streak day is at least N.
bool programDayUnlocked(int streakDay, int day) => day <= streakDay;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    AppState.instance.streakStartMs = null;
    AppState.instance.pendingCelebrations.clear();
    // The ffi database file persists across tests in this file — clean the
    // tables this file touches so each test starts empty.
    final db = await DayOneDatabase.instance.database;
    await db.delete('letters');
    await DayOneDatabase.instance.close();
  });

  group('Program content: 90 tasks', () {
    test('exactly 90 tasks, days 1..90 in order', () {
      expect(programTasks.length, 90);
      for (var i = 0; i < 90; i++) {
        expect(programTasks[i].day, i + 1);
      }
    });

    test('every task has non-empty title, opener, action', () {
      for (final t in programTasks) {
        expect(t.title.trim(), isNotEmpty, reason: 'day ${t.day} title');
        expect(t.opener.trim(), isNotEmpty, reason: 'day ${t.day} opener');
        expect(t.action.trim(), isNotEmpty, reason: 'day ${t.day} action');
      }
    });

    test('no banned clichés or therapy-jargon', () {
      const banned = [
        'time heals all wounds',
        'just move on',
        'everything happens for a reason',
        'what doesn\'t kill you',
        'process your trauma',
        'attachment style',
      ];
      for (final t in programTasks) {
        final text = '${t.title} ${t.opener} ${t.action}'.toLowerCase();
        for (final phrase in banned) {
          expect(text.contains(phrase), isFalse,
              reason: 'day ${t.day} contains banned phrase "$phrase"');
        }
      }
    });

    test('titles are unique (no copy-paste tasks)', () {
      final titles = programTasks.map((t) => t.title.toLowerCase()).toSet();
      expect(titles.length, 90);
    });
  });

  group('Program unlock logic', () {
    test('day 1 unlocks on streak day 1', () {
      expect(programDayUnlocked(1, 1), isTrue);
    });

    test('future days stay locked', () {
      expect(programDayUnlocked(5, 6), isFalse);
      expect(programDayUnlocked(5, 90), isFalse);
    });

    test('past days unlock', () {
      expect(programDayUnlocked(30, 30), isTrue);
      expect(programDayUnlocked(30, 1), isTrue);
    });

    test('matches displayDay semantics', () {
      // displayDay(elapsed) = elapsed + 1; program day N needs displayDay >= N.
      expect(streak_math.displayDay(0), 1);
      expect(programDayUnlocked(streak_math.displayDay(4), 5), isTrue);
      expect(programDayUnlocked(streak_math.displayDay(4), 6), isFalse);
    });
  });

  group('Program completion prefs', () {
    test('round-trips a set of done days', () async {
      final prefs = await PrefsService.instance();
      expect(prefs.programDoneDays, isEmpty);
      await prefs.setProgramDoneDays({1, 2, 3});
      expect(prefs.programDoneDays, {1, 2, 3});
      await prefs.setProgramDoneDays({});
      expect(prefs.programDoneDays, isEmpty);
    });
  });

  group('Letter vault DB', () {
    test('insert, list newest-first, delete', () async {
      final db = DayOneDatabase.instance;
      final id1 = await db.insertLetter(title: 'First', body: 'Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final id2 = await db.insertLetter(title: '', body: 'World');
      expect(id2, greaterThan(id1));

      var letters = await db.allLetters();
      expect(letters.length, 2);
      // Newest first.
      expect(letters.first['id'], id2);
      expect(await db.letterCount(), 2);

      await db.deleteLetter(id2);
      letters = await db.allLetters();
      expect(letters.length, 1);
      expect(letters.first['id'], id1);
    });

    test('wipeAll clears letters too', () async {
      final db = DayOneDatabase.instance;
      await db.insertLetter(title: 'x', body: 'y');
      expect(await db.letterCount(), 1);
      await db.wipeAll();
      expect(await db.letterCount(), 0);
    });
  });

  group('ProgramScreen widget', () {
    testWidgets('renders 90 day tiles and progress header',
        (tester) async {
      // Streak day 5 -> days 1..5 unlocked, rest locked.
      AppState.instance.streakStartMs =
          DateTime.now().millisecondsSinceEpoch - 4 * 86400000;
      await tester.pumpWidget(_wrap(const ProgramScreen()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('90-day program'), findsOneWidget);
      expect(find.text('Your journey'), findsOneWidget);
      // 90 tiles: unlocked show numbers, locked show lock icons.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('VaultScreen widget', () {
    testWidgets('empty state renders with warm copy', (tester) async {
      // DB-backed screens must pump inside runAsync: sqflite_ffi deadlocks
      // under testWidgets' FakeAsync zone (established repo pattern).
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Letter vault'), findsOneWidget);
      expect(find.text('The unsent-letter vault'), findsOneWidget);
      expect(find.text('Write your first letter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sealed letter appears in the list', (tester) async {
      await tester.runAsync(() async {
        await DayOneDatabase.instance
            .insertLetter(title: 'To you', body: 'Everything unsaid.');
        await tester.pumpWidget(_wrap(const VaultScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('To you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
