import 'package:day_one_nocontact/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed reference: 2026-10-15 12:00:00 UTC.
  final t0 = DateTime.utc(2026, 10, 15, 12).millisecondsSinceEpoch;
  int daysLater(double d) =>
      t0 + (d * Duration.millisecondsPerDay).round();

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
    test('unlock at exact day boundaries', () {
      expect(unlockedMilestones(6), isEmpty);
      expect(unlockedMilestones(7), [7]);
      expect(unlockedMilestones(14), [7, 14]);
      expect(unlockedMilestones(90), [7, 14, 30, 60, 90]);
      expect(unlockedMilestones(200), [7, 14, 30, 60, 90]);
    });

    test('nextMilestone points forward', () {
      expect(nextMilestone(0), 7);
      expect(nextMilestone(7), 14);
      expect(nextMilestone(29), 30);
      expect(nextMilestone(90), isNull);
      expect(nextMilestone(500), isNull);
    });

    test('progressToNext is fractional and capped', () {
      expect(progressToNext(0), 0.0);
      expect(progressToNext(90), 1.0);
      // Day 23 of 7..30 span: (23-14)/(30-14) = 9/16
      expect(progressToNext(23), closeTo(9 / 16, 0.0001));
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
    test('uses Day 0 brand language at start', () {
      expect(dayLabel(0), 'Day 0');
      expect(dayLabel(23), 'Day 23');
    });
  });
}
