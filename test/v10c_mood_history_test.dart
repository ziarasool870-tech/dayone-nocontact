/// v10-C: Mood history — week-strip mood tints, 30-day "Mood journey"
/// (FREE for all), kind insight rules, empty state, overflow safety.
///
/// Covers: mood color mapping x5 + neutral, mood words, 30-day window,
/// insight rules (empty/improving/declining/steady/low), journey screen
/// with seeded DB (insight + 30 cells + tap detail), empty state, FREE
/// (no paywall in tree), small-screen overflow.
library;

import 'package:day_one_nocontact/core/mood_colors.dart';
import 'package:day_one_nocontact/data/database.dart';
import 'package:day_one_nocontact/screens/mood_journey_screen.dart';
import 'package:day_one_nocontact/screens/paywall_screen.dart';
import 'package:day_one_nocontact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: DayOneTheme.light(),
      home: child,
    );

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> _row(DateTime d, int mood, {bool held = true}) =>
    {'date': _key(d), 'mood': mood, 'held': held ? 1 : 0};

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('mood color mapping', () {
    test('five moods map to warm, non-red colors', () {
      expect(MoodColors.forMood(0), MoodColors.rough);
      expect(MoodColors.forMood(1), MoodColors.low);
      expect(MoodColors.forMood(2), MoodColors.okay);
      expect(MoodColors.forMood(3), MoodColors.good);
      expect(MoodColors.forMood(4), MoodColors.great);
      // None is harsh red.
      for (var i = 0; i < 5; i++) {
        final c = MoodColors.forMood(i);
        expect(c, isNot(equals(const Color(0xFFFF0000))));
      }
    });

    test('null and out-of-range moods map to neutral', () {
      expect(MoodColors.forMood(null), MoodColors.none);
      expect(MoodColors.forMood(-1), MoodColors.none);
      expect(MoodColors.forMood(5), MoodColors.none);
    });

    test('mood words in order', () {
      expect(moodWords, ['Rough', 'Low', 'Okay', 'Good', 'Great']);
      expect(MoodColors.wordFor(0), 'Rough');
      expect(MoodColors.wordFor(4), 'Great');
      expect(MoodColors.wordFor(null), 'No check-in');
    });
  });

  group('30-day window', () {
    test('builds 30 days ending today, oldest first', () {
      final now = DateTime(2026, 10, 16);
      final days = lastNMoodDays(
          [_row(DateTime(2026, 10, 16), 4), _row(DateTime(2026, 10, 1), 0)],
          30,
          now: now);
      expect(days.length, 30);
      expect(days.first.date.day, 17); // Sep 17
      expect(days.first.date.month, 9);
      expect(days.last.date.day, 16); // today
      expect(days.first.mood, isNull); // no row -> null
      expect(days[14].mood, 0); // Oct 1
      expect(days.last.mood, 4); // today
    });

    test('invalid mood values become null, held parsed', () {
      final now = DateTime(2026, 10, 16);
      final days = lastNMoodDays([
        {'date': '2026-10-16', 'mood': 9, 'held': 0},
      ], 30, now: now);
      expect(days.last.mood, isNull);
      expect(days.last.held, isFalse);
    });
  });

  group('insight rules (always kind, never shaming)', () {
    List<MoodDay> mdays(List<int?> moods, {DateTime? now}) {
      final base = now ?? DateTime(2026, 10, 16);
      return List.generate(
          moods.length,
          (i) => MoodDay(
              date: DateTime(base.year, base.month, base.day - moods.length + 1 + i),
              mood: moods[i],
              held: true));
    }

    test('empty -> null (caller shows empty state)', () {
      expect(moodInsight(mdays([null, null])), isNull);
      expect(moodInsight([]), isNull);
    });

    test('improving trend', () {
      expect(moodInsight(mdays([0, 1, 0, 1, 3, 4, 3, 4])),
          'Your days are getting lighter.');
    });

    test('declining trend is gentle', () {
      final line = moodInsight(mdays([4, 3, 4, 3, 1, 0, 1, 0]))!;
      expect(line, contains('be gentle with yourself'));
      expect(line, isNot(contains('sad')));
    });

    test('steady high', () {
      expect(moodInsight(mdays([4, 3, 4, 3])), 'Steady and strong — keep going.');
    });

    test('mid level', () {
      expect(moodInsight(mdays([2, 2, 2, 2])),
          contains("isn't a straight line"));
    });

    test('low level faces forward', () {
      final line = moodInsight(mdays([0, 1, 0, 1]))!;
      expect(line, contains('Look how far'));
      expect(line, isNot(contains('too long')));
    });

    test('single entry does not crash', () {
      expect(moodInsight(mdays([2])), isNotNull);
    });
  });

  group('MoodJourneyScreen (seeded DB)', () {
    Future<void> seed(List<int> moods) async {
      final db = await DayOneDatabase.instance.database;
      await db.delete('checkins');
      final now = DateTime.now();
      for (var i = 0; i < moods.length; i++) {
        final d = DateTime(now.year, now.month, now.day - moods.length + 1 + i);
        await DayOneDatabase.instance
            .upsertCheckIn(_key(d), held: true, mood: moods[i]);
      }
    }

    testWidgets('shows insight + 30 day cells + tap detail',
        (tester) async {
      await tester.runAsync(() => seed([1, 2, 2, 3, 4, 4]));
      await tester.runAsync(() async {
        await tester.pumpWidget(_wrap(const MoodJourneyScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();

      expect(find.text('Mood journey'), findsOneWidget);
      expect(find.textContaining('getting lighter'), findsOneWidget);
      // 30 day-number circles in the grid.
      expect(find.byType(AnimatedContainer), findsNWidgets(30));
      expect(find.byType(PaywallScreen), findsNothing); // FREE

      // Tap a day -> detail card with the mood word.
      await tester.tap(find.byType(AnimatedContainer).first);
      await tester.pump();
      expect(find.textContaining('·'), findsWidgets);
    });

    testWidgets('empty state when no check-ins', (tester) async {
      await tester.runAsync(() async {
        final db = await DayOneDatabase.instance.database;
        await db.delete('checkins');
        await tester.pumpWidget(_wrap(const MoodJourneyScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
      expect(
          find.text(
              'Check in each day and your mood story will appear here.'),
          findsOneWidget);
    });

    testWidgets('no overflow on a small screen with large fonts',
        (tester) async {
      await tester.runAsync(() => seed([0, 1, 2, 3, 4]));
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(() async {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _wrap(const MoodJourneyScreen()),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
