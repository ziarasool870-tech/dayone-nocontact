/// Mood history building blocks: words, warm color scale, 30-day window,
/// and the gentle insight rules. All pure and unit-testable.
///
/// Emotional guardrail: nothing here ever shames a low mood. The color
/// scale is warm (no harsh red), and every insight faces forward.
library;

import 'package:flutter/material.dart';

/// The five mood words, index 0-4. Must match the check-in row order.
const moodWords = ['Rough', 'Low', 'Okay', 'Good', 'Great'];

class MoodColors {
  MoodColors._();

  static const rough = Color(0xFFC7A891); // muted clay
  static const low = Color(0xFFDEC49B); // soft sand
  static const okay = Color(0xFFE8C89F); // warm gold
  static const good = Color(0xFFA9C6A4); // soft sage
  static const great = Color(0xFF6FA287); // deeper warm green
  static const none = Color(0xFFF4F1EC); // no check-in (neutral)

  /// Warm tint for a mood index 0-4; [none] for null/out-of-range.
  static Color forMood(int? mood) {
    switch (mood) {
      case 0:
        return rough;
      case 1:
        return low;
      case 2:
        return okay;
      case 3:
        return good;
      case 4:
        return great;
      default:
        return none;
    }
  }

  static String wordFor(int? mood) =>
      (mood != null && mood >= 0 && mood < moodWords.length)
          ? moodWords[mood]
          : 'No check-in';
}

/// One calendar day of mood history. [mood] is null when the user did not
/// check in that day.
class MoodDay {
  const MoodDay({required this.date, required this.mood, required this.held});

  final DateTime date;
  final int? mood;
  final bool held;
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Builds the last [days] calendar days (oldest first, ending today) from
/// raw check-in rows (`date` as yyyy-MM-dd, `mood` int, `held` int).
List<MoodDay> lastNMoodDays(List<Map<String, Object?>> rows, int days,
    {DateTime? now}) {
  final today = now ?? DateTime.now();
  final byDate = <String, Map<String, Object?>>{};
  for (final r in rows) {
    final d = r['date'];
    if (d is String) byDate[d] = r;
  }
  return List.generate(days, (i) {
    final d = DateTime(today.year, today.month, today.day - days + 1 + i);
    final r = byDate[_key(d)];
    final mood = (r?['mood'] as num?)?.toInt();
    return MoodDay(
      date: d,
      mood: (mood != null && mood >= 0 && mood <= 4) ? mood : null,
      held: (r?['held'] as num?)?.toInt() == 1,
    );
  });
}

/// Gentle, forward-looking insight line for the Mood journey screen.
/// Returns null when there is no mood data (caller shows the empty state).
/// Never shames, never clinical.
String? moodInsight(List<MoodDay> days) {
  final withMood = days.where((d) => d.mood != null).toList();
  if (withMood.isEmpty) return null;

  double avg(Iterable<MoodDay> ds) =>
      ds.map((d) => d.mood!).reduce((a, b) => a + b) / ds.length;

  // Trend: compare the newer half of the last 14 days against the older half.
  final recent = withMood.length > 14
      ? withMood.sublist(withMood.length - 14)
      : withMood;
  if (recent.length >= 4) {
    final half = recent.length ~/ 2;
    final older = recent.sublist(0, half);
    final newer = recent.sublist(half);
    final delta = avg(newer) - avg(older);
    if (delta >= 0.5) return 'Your days are getting lighter.';
    if (delta <= -0.5) {
      return 'Some heavy days lately — be gentle with yourself. They pass.';
    }
  }

  final level = avg(recent);
  if (level >= 3) return 'Steady and strong — keep going.';
  if (level >= 2) {
    return "Healing isn't a straight line — and you're still walking it.";
  }
  return "Rough days pass. Look how far you've come.";
}
