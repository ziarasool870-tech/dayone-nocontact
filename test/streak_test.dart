import 'package:day_one_nocontact/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed reference: 2026-10-15 12:00:00 UTC.
  final t0 = DateTime.utc(2026, 10, 15, 12).millisecondsSinceEpoch;
  int daysLater(double d) => t0 + (d * Duration.millisecondsPerDay).round();

  group('daysElapsed', () {
    test('is 0 at the exact start moment', () {
      expect(daysElapsed(t0, t0), 0);
    });

    test('floors partial days', () {
      expect(daysElapsed(t0, daysLater(0.9)), 0);
      expect(daysElapsed(t0, daysLater(1.0)), 1);
      expect(daysElapsed(t0, daysLater(22.99)), 22);
      expect(daysElapsed(t0, daysLater(23.0)), 23);
    });

    test('never goes negative when now is before start', () {
      expect(daysElapsed(t0, t0 - 1000), 0);
    });
  });

  group('elapsedParts', () {
    test('breaks down 23d 14h 32m 18s like the mockup', () {
      final now = t0 +
          Duration(days: 23, hours: 14, minutes: 32, seconds: 18)
              .inMilliseconds;
      final p = elapsedParts(t0, now);
      expect(p.days, 23);
      expect(p.hours, 14);
      expect(p.minutes, 32);
      expect(p.seconds, 18);
    });

    test('is all zeros at start', () {
      final p = elapsedParts(t0, t0);
      expect((p.days, p.hours, p.minutes, p.seconds), (0, 0, 0, 0));
    });
  });

  group('milestones', () {
    // v4: milestones unlock against the DISPLAY day (start day = Day 1).
    // v6: extended to 100 / 180 / 365 — same display-day semantics.
    test('unlock at exact day boundaries', () {
      expect(unlockedMilestones(5), isEmpty); // display Day 6
      expect(unlockedMilestones(6), [7]); // display Day 7
      expect(unlockedMilestones(7), [7]);
      expect(unlockedMilestones(14), [7, 14]);
      expect(unlockedMilestones(90), [7, 14, 30, 60, 90]);
      expect(unlockedMilestones(99), [7, 14, 30, 60, 90, 100]); // Day 100
      expect(unlockedMilestones(179), [7, 14, 30, 60, 90, 100, 180]);
      expect(unlockedMilestones(364),
          [7, 14, 30, 60, 90, 100, 180, 365]); // Day 365
      expect(unlockedMilestones(500), [7, 14, 30, 60, 90, 100, 180, 365]);
    });

    test('nextMilestone points forward', () {
      expect(nextMilestone(0), 7); // display Day 1
      expect(nextMilestone(6), 14); // display Day 7 -> next is 14
      expect(nextMilestone(7), 14);
      expect(nextMilestone(29), 60); // display Day 30 -> next is 60
      expect(nextMilestone(89), 100); // display Day 90 -> next is 100
      expect(nextMilestone(99), 180); // display Day 100 -> next is 180
      expect(nextMilestone(179), 365); // display Day 180 -> next is 365
      expect(nextMilestone(364), isNull); // display Day 365 -> all unlocked
      expect(nextMilestone(500), isNull);
    });

    test('progressToNext is fractional and capped', () {
      // display Day 1 of 0..7 span: (1-0)/7
      expect(progressToNext(0), closeTo(1 / 7, 0.0001));
      expect(progressToNext(364), 1.0);
      // display Day 24 of 14..30 span: (24-14)/(30-14) = 10/16
      expect(progressToNext(23), closeTo(10 / 16, 0.0001));
      // display Day 95 of 90..100 span: (95-90)/(100-90) = 5/10
      expect(progressToNext(94), closeTo(5 / 10, 0.0001));
    });
  });

  group('recordRelapse', () {
    test('restarts counter but keeps longest and total', () {
      final start = daysLater(-23); // 23-day streak
      final state = const StreakState(currentStartMs: 0)
          .copyWith(currentStartMs: start, longestDays: 31, totalCleanDays: 40);
      final after = recordRelapse(state, t0);

      expect(after.currentStartMs, t0);
      expect(daysElapsed(after.currentStartMs, t0), 0);
      // 23 < longest 31, so longest is untouched; total gains 23
      expect(after.longestDays, 31);
      expect(after.totalCleanDays, 63);
      expect(after.history.length, 1);
      expect(after.history.single.days, 23);
    });

    test('a new record updates longest', () {
      final start = daysLater(-40);
      const state = StreakState(currentStartMs: 0);
      final s2 = state.copyWith(currentStartMs: start);
      final after = recordRelapse(s2, t0);
      expect(after.longestDays, 40);
      expect(after.totalCleanDays, 40);
    });

    test('sub-day relapse restarts without polluting history', () {
      final start = t0 - const Duration(hours: 5).inMilliseconds;
      const state = StreakState(currentStartMs: 0);
      final s2 = state.copyWith(currentStartMs: start);
      final after = recordRelapse(s2, t0);
      expect(after.currentStartMs, t0);
      expect(after.history, isEmpty);
      expect(after.longestDays, 0);
      expect(after.totalCleanDays, 0);
    });

    test('multiple relapses accumulate history, never erase', () {
      var state = StreakState(currentStartMs: daysLater(-10));
      state = recordRelapse(state, t0); // 10-day streak banked
      final later = t0 + Duration(days: 5).inMilliseconds;
      state = recordRelapse(state, later); // 5-day streak banked
      expect(state.history.length, 2);
      expect(state.totalCleanDays, 15);
      expect(state.longestDays, 10);
    });
  });

  group('quoteIndexFor', () {
    test('rotates deterministically within the pack', () {
      final jan1 = DateTime(2026, 1, 1);
      final jan2 = DateTime(2026, 1, 2);
      expect(quoteIndexFor(jan1, 30), 0);
      expect(quoteIndexFor(jan2, 30), 1);
      expect(quoteIndexFor(DateTime(2026, 1, 31), 30), 0); // wraps
    });
  });

  group('dayLabel', () {
    // v4: Day-1 brand language — the start day itself is Day 1.
    test('labels the start day as Day 1', () {
      expect(dayLabel(0), 'Day 1');
      expect(dayLabel(23), 'Day 24');
    });

    test('displayDay counts the start day as day one', () {
      expect(displayDay(0), 1);
      expect(displayDay(8), 9);
    });
  });
}
