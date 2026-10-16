/// 90-day guided program: one 2-minute healing task per day.
/// Pro-gated. Program Day N unlocks when the no-contact streak reaches Day N.
library;

import 'package:flutter/material.dart';

import '../core/program_tasks.dart';
import '../data/prefs.dart';
import '../domain/streak.dart' as streak_math;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  Set<int> _done = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final prefs = await PrefsService.instance();
    if (mounted) {
      setState(() {
        _done = prefs.programDoneDays;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final streakDay = streak_math.displayDay(app.elapsedDays);
    final doneCount = _done.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('90-day program'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Progress header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your journey',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            Text('$doneCount of 90',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DayOneColors.terracottaDeep)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: doneCount / 90,
                            minHeight: 10,
                            backgroundColor: DayOneColors.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                DayOneColors.terracotta),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'One small task a day. Two minutes. '
                          'Day $streakDay of your no-contact journey.',
                          style: const TextStyle(
                              fontSize: 14,
                              color: DayOneColors.muted,
                              height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
                // Kind note after a streak reset: the program follows the
                // same journey, and starting over is never punished here.
                if (streakDay <= 3 && _done.isEmpty && app.longestDays > 3) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🤍', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Starting fresh? Your tasks waited for you. '
                              'Day 1 is ready whenever you are — no judgment here.',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: DayOneColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('All 90 days',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: 90,
                  itemBuilder: (ctx, i) {
                    final day = i + 1;
                    final unlocked = day <= streakDay;
                    final done = _done.contains(day);
                    return _DayTile(
                      day: day,
                      unlocked: unlocked,
                      done: done,
                      onTap: unlocked
                          ? () async {
                              final changed =
                                  await Navigator.of(context).push<bool>(
                                FadeSlidePageRoute(
                                    child: TaskDetailScreen(day: day)),
                              );
                              if (changed == true) _reload();
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Day $day unlocks on Day $day of no contact. '
                                      'You\'re on Day $streakDay — keep going.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.unlocked,
    required this.done,
    required this.onTap,
  });

  final int day;
  final bool unlocked;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? DayOneColors.sageSoft
        : unlocked
            ? DayOneColors.terracottaPale
            : DayOneColors.card;
    final fg = done
        ? DayOneColors.sage
        : unlocked
            ? DayOneColors.terracottaDeep
            : DayOneColors.faint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done
                ? DayOneColors.sage.withValues(alpha: 0.4)
                : unlocked
                    ? DayOneColors.terracotta.withValues(alpha: 0.35)
                    : DayOneColors.cardBorder,
          ),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, color: DayOneColors.sage, size: 20)
              : unlocked
                  ? Text('$day',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: fg))
                  : const Icon(Icons.lock_outline,
                      color: DayOneColors.faint, size: 18),
        ),
      ),
    );
  }
}

/// Detail view for a single day's task.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.day});

  final int day;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _done = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PrefsService.instance();
    if (mounted) {
      setState(() {
        _done = prefs.programDoneDays.contains(widget.day);
        _loading = false;
      });
    }
  }

  Future<void> _toggleDone() async {
    final prefs = await PrefsService.instance();
    final days = prefs.programDoneDays;
    if (_done) {
      days.remove(widget.day);
    } else {
      days.add(widget.day);
    }
    await prefs.setProgramDoneDays(days);
    if (!mounted) return;
    setState(() => _done = !_done);
    if (_done) {
      // Small warm confirmation — no confetti circus.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Done. Two minutes for yourself — that counts. 🤍'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Pop after a beat so the list refreshes behind.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final task = programTasks[widget.day - 1];
    return Scaffold(
      appBar: AppBar(title: Text('Day ${task.day}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(task.opener,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.55,
                                color: DayOneColors.ink,
                                fontStyle: FontStyle.italic)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DayOneColors.terracottaPale,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: DayOneColors.terracottaDeep,
                                  size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(task.action,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        height: 1.55,
                                        color: DayOneColors.ink)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _toggleDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _done ? DayOneColors.sage : DayOneColors.terracotta,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(_done ? 'Done ✓ — tap to undo' : 'Mark as done'),
                  ),
                ),
              ],
            ),
    );
  }
}
