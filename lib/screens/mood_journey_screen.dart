/// "Mood journey" — the last 30 days of check-in moods as a calm grid,
/// with one gentle, forward-looking insight line on top.
///
/// FREE for every user (no Pro gate). Never shames a low mood.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/mood_colors.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';

class MoodJourneyScreen extends StatefulWidget {
  const MoodJourneyScreen({super.key});

  @override
  State<MoodJourneyScreen> createState() => _MoodJourneyScreenState();
}

class _MoodJourneyScreenState extends State<MoodJourneyScreen> {
  MoodDay? _selected;
  // Cached: creating a new future per build would reset the FutureBuilder
  // (spinner flash) on every setState, e.g. when selecting a day.
  late final Future<List<Map<String, Object?>>> _checkIns =
      DayOneDatabase.instance.allCheckIns();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mood journey')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _checkIns,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = lastNMoodDays(snap.data ?? const [], 30);
          final insight = moodInsight(days);
          if (insight == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Check in each day and your mood story will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: DayOneColors.muted,
                      height: 1.5),
                ),
              ),
            );
          }
          final selected = _selected;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: DayOneColors.goldSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('🌅', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(insight,
                              style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: DayOneColors.ink,
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Last 30 days',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final isToday = i == days.length - 1;
                    final isSelected = selected?.date == d.date;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MoodColors.forMood(d.mood),
                          border: (isToday || isSelected)
                              ? Border.all(
                                  color: DayOneColors.terracotta, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text('${d.date.day}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DayOneColors.ink)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (selected != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: MoodColors.forMood(selected.mood),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${DateFormat('MMM d').format(selected.date)} · ${MoodColors.wordFor(selected.mood)}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    for (var i = 0; i < moodWords.length; i++)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MoodColors.forMood(i),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Text('Rough → Great',
                        style: TextStyle(
                            fontSize: 10.5, color: DayOneColors.muted)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
