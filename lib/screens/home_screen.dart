/// Home tab: hero streak timer, daily healing quote, check-in card,
/// next-milestone progress, and the week strip.
library;

import 'package:flutter/material.dart';

import '../core/content.dart';
import '../data/database.dart';
import '../domain/streak.dart' as streak_math;
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool? _checkedInHeld;
  int _mood = 2;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadCheckIn();
    // Catch milestones unlocked while away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  Future<void> _loadCheckIn() async {
    final row = await DayOneDatabase.instance.checkInFor(AppState.todayKey());
    if (mounted && row != null) {
      setState(() {
        _checkedInHeld = (row['held'] as num?)?.toInt() == 1;
        _mood = (row['mood'] as num?)?.toInt() ?? 2;
      });
    }
  }

  Future<void> _celebrate() async {
    final app = AppState.instance;
    if (app.pendingCelebrations.isEmpty || !mounted) return;
    final days = List<int>.from(app.pendingCelebrations);
    app.consumeCelebrations();
    for (final d in days) {
      if (!mounted) break;
      await MilestoneCelebration.show(context, d,
          message: milestoneMessages[d]);
    }
  }

  Future<void> _checkIn(bool held) async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    await DayOneDatabase.instance.upsertCheckIn(
      AppState.todayKey(),
      held: held,
      mood: _mood,
    );
    if (mounted) {
      setState(() {
        _checkedInHeld = held;
        _checkingIn = false;
      });
      HeartPop.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(held
              ? 'Held strong. That counts for a lot.'
              : 'Logged honestly. Tomorrow is a new day.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _relapseSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        // Scrollable so the sheet never overflows on small screens at
        // large system font sizes.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(relapseTitle, style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(relapseBody,
                  style: const TextStyle(
                      fontSize: 16, height: 1.55, color: DayOneColors.muted)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await AppState.instance.relapse();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Day 1 again. Your history stays with you.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Restart at Day 1'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Keep my streak',
                      style: TextStyle(color: DayOneColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final app = AppState.instance;
        final startMs = app.streakStartMs;
        if (startMs == null) {
          return const Center(child: Text('Setting up your Day One…'));
        }
        final days = app.elapsedDays;
        final next = streak_math.nextMilestone(days);
        final progress = streak_math.progressToNext(days);
        final quote = healingQuotes[
            streak_math.quoteIndexFor(DateTime.now(), healingQuotes.length)];

        return RefreshIndicator(
          onRefresh: () async {
            await app.refreshMilestones();
            await _celebrate();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TickingCounter(startMs: startMs),
                const SizedBox(height: 16),
                // Daily quote
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('“',
                            style: TextStyle(
                                fontSize: 28,
                                height: 0.9,
                                color: DayOneColors.terracotta,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(quote,
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: DayOneColors.ink,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Check-in card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Did you hold no contact today?',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          _checkedInHeld == null
                              ? 'Be honest — it only helps you.'
                              : _checkedInHeld!
                                  ? 'Logged: held strong today.'
                                  : 'Logged: slipped today. It happens.',
                          style: const TextStyle(
                              fontSize: 14.5, color: DayOneColors.muted),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _checkingIn ? null : () => _checkIn(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DayOneColors.sage,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('Yes, held strong',
                                    textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _checkingIn ? null : () => _checkIn(false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('I slipped'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Mood right now',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: DayOneColors.muted)),
                        const SizedBox(height: 6),
                        _moodRow(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _relapseSheet,
                            child: const Text(
                              'I broke no contact — restart',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: DayOneColors.muted,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Next milestone
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                next == null
                                    ? 'All milestones unlocked'
                                    : 'Next milestone · Day $next',
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (next != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                  '${next - streak_math.displayDay(days)} to go',
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: DayOneColors.terracotta)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF1EAE2),
                              valueColor: const AlwaysStoppedAnimation(
                                  DayOneColors.terracotta),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _weekStrip(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _moodRow() {
    const moods = ['Rough', 'Low', 'Okay', 'Good', 'Great'];
    return Row(
      children: List.generate(5, (i) {
        final selected = _mood == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _mood = i);
              // Already checked in today? Keep the saved mood in sync
              // instead of silently dropping the change on reload.
              if (_checkedInHeld != null) {
                DayOneDatabase.instance.upsertCheckIn(
                  AppState.todayKey(),
                  held: _checkedInHeld!,
                  mood: i,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? DayOneColors.terracottaSoft
                    : const Color(0xFFF4F1EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      selected ? DayOneColors.terracotta : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text(moods[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? DayOneColors.terracottaDeep
                          : DayOneColors.muted)),
            ),
          ),
        );
      }),
    );
  }

  Widget _weekStrip() {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: DayOneDatabase.instance.allCheckIns(),
      builder: (context, snap) {
        final byDate = <String, bool>{};
        for (final r in snap.data ?? const []) {
          byDate[r['date'] as String] = (r['held'] as num?)?.toInt() == 1;
        }
        final now = DateTime.now();
        final days = List.generate(
            7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This week',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: days.map((d) {
                    final key =
                        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    final held = byDate[key];
                    final isToday = key == AppState.todayKey();
                    return Column(
                      children: [
                        Text('SMTWTFS'[d.weekday % 7],
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: DayOneColors.muted)),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: held == null
                                ? const Color(0xFFF4F1EC)
                                : held
                                    ? DayOneColors.sage
                                    : DayOneColors.terracotta
                                        .withValues(alpha: 0.35),
                            border: isToday
                                ? Border.all(
                                    color: DayOneColors.terracotta, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text('${d.day}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: held == true
                                      ? Colors.white
                                      : DayOneColors.ink)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
