/// Pure streak mathematics for Day One: No Contact.
///
/// Zero Flutter dependencies — fully unit-testable with `flutter test`.
///
/// Model notes (from the locked spec):
/// - "Day N" headline = full elapsed days since Day-0 start (Day 0 is brand
///   language: "Day 0 again — most people restart twice").
/// - Relapse restarts the counter ONLY. History (longest streak, total clean
///   days, past streak records) is never erased.
library;

/// One completed (or ended) streak period kept in history.
class StreakRecord {
  const StreakRecord({
    required this.startMs,
    required this.endMs,
    required this.days,
  });

  final int startMs;
  final int endMs;
  final int days;

  Map<String, Object?> toMap() => {
        'start_ms': startMs,
        'end_ms': endMs,
        'days': days,
      };

  factory StreakRecord.fromMap(Map<String, Object?> map) => StreakRecord(
        startMs: (map['start_ms'] as num).toInt(),
        endMs: (map['end_ms'] as num).toInt(),
        days: (map['days'] as num).toInt(),
      );
}

/// Immutable snapshot of all streak state.
class StreakState {
  const StreakState({
    required this.currentStartMs,
    this.longestDays = 0,
    this.totalCleanDays = 0,
    this.history = const [],
  });

  final int currentStartMs;
  final int longestDays;
  final int totalCleanDays;
  final List<StreakRecord> history;

  StreakState copyWith({
    int? currentStartMs,
    int? longestDays,
    int? totalCleanDays,
    List<StreakRecord>? history,
  }) =>
      StreakState(
        currentStartMs: currentStartMs ?? this.currentStartMs,
        longestDays: longestDays ?? this.longestDays,
        totalCleanDays: totalCleanDays ?? this.totalCleanDays,
        history: history ?? this.history,
      );
}

/// Milestone days that unlock shareable cards. Single source of truth.
const List<int> milestoneDays = [7, 14, 30, 60, 90];

/// Full elapsed days between [startMs] and [nowMs], floored. Never negative.
int daysElapsed(int startMs, int nowMs) {
  if (nowMs < startMs) return 0;
  return DateTime.fromMillisecondsSinceEpoch(nowMs)
      .difference(DateTime.fromMillisecondsSinceEpoch(startMs))
      .inDays;
}

/// Elapsed time broken into display parts.
({int days, int hours, int minutes, int seconds}) elapsedParts(
    int startMs, int nowMs) {
  final d = Duration(milliseconds: nowMs < startMs ? 0 : nowMs - startMs);
  return (
    days: d.inDays,
    hours: d.inHours % 24,
    minutes: d.inMinutes % 60,
    seconds: d.inSeconds % 60,
  );
}

/// Headline label, e.g. "Day 0", "Day 23".
String dayLabel(int elapsedDays) => 'Day $elapsedDays';

/// Milestones unlocked at [elapsedDays].
List<int> unlockedMilestones(int elapsedDays) =>
    milestoneDays.where((m) => elapsedDays >= m).toList();

/// Next milestone after [elapsedDays], or null when all are unlocked.
int? nextMilestone(int elapsedDays) {
  for (final m in milestoneDays) {
    if (elapsedDays < m) return m;
  }
  return null;
}

/// Fraction 0.0–1.0 of progress toward the next milestone.
/// Returns 1.0 when every milestone is unlocked.
double progressToNext(int elapsedDays) {
  final next = nextMilestone(elapsedDays);
  if (next == null) return 1.0;
  final idx = milestoneDays.indexOf(next);
  final prev = idx == 0 ? 0 : milestoneDays[idx - 1];
  final span = next - prev;
  if (span <= 0) return 1.0;
  return ((elapsedDays - prev) / span).clamp(0.0, 1.0);
}

/// Records a relapse at [nowMs]: the current streak is closed into history
/// (only when it lasted at least one full day), longest/total are updated,
/// and the counter restarts at [nowMs]. History is never erased.
StreakState recordRelapse(StreakState state, int nowMs) {
  final days = daysElapsed(state.currentStartMs, nowMs);
  final history = List<StreakRecord>.from(state.history);
  var longest = state.longestDays;
  var total = state.totalCleanDays;
  if (days >= 1) {
    history.add(StreakRecord(
      startMs: state.currentStartMs,
      endMs: nowMs,
      days: days,
    ));
    if (days > longest) longest = days;
    total += days;
  }
  return state.copyWith(
    currentStartMs: nowMs,
    longestDays: longest,
    totalCleanDays: total,
    history: history,
  );
}

/// Quote of the day index from a pack of [packLength] quotes.
int quoteIndexFor(DateTime date, int packLength) {
  if (packLength <= 0) return 0;
  final dayOfYear =
      date.difference(DateTime(date.year, 1, 1)).inDays;
  return dayOfYear % packLength;
}
