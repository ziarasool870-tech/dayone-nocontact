/// Onboarding: welcome → start date → quick setup. Under 30 seconds.
/// No quiz fatigue, no account, no paywall before value.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;
  DateTime _startDate = DateTime.now();
  bool _forSelf = true;

  void _next() {
    if (_page < 2) {
      _pager.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await AppState.instance.setStartDate(_startDate);
    widget.onFinished();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(),
                  _datePage(),
                  _setupPage(),
                ],
              ),
            ),
            _dots(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_page == 2 ? 'Enter Day One' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final on = i == _page;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: on ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: on
                  ? DayOneColors.terracotta
                  : DayOneColors.terracotta.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------ page 1

  Widget _welcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                DayOneColors.terracotta,
                Color(0xFFE8A07E),
              ]),
            ),
            alignment: Alignment.center,
            child: const Text('♥',
                style: TextStyle(fontSize: 44, color: Colors.white)),
          ),
          const SizedBox(height: 26),
          const Text('DAY ONE',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 8),
          const Text('No Contact',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: DayOneColors.ink)),
          const SizedBox(height: 14),
          const Text(
            'Your breakup recovery companion.\nOne day at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.5, color: DayOneColors.muted),
          ),
          const SizedBox(height: 18),
          const Text('Free forever where it matters.',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: DayOneColors.terracottaDeep)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ page 2

  Widget _datePage() {
    final now = DateTime.now();
    // Simple 7-day strip: 3 days ago … 3 days ahead.
    final days = List.generate(
        7, (i) => DateTime(now.year, now.month, now.day - 3 + i));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          const Text('STEP 1 OF 2',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 10),
          const Text('When did\nno contact start?',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DayOneColors.ink,
                  height: 1.15)),
          const SizedBox(height: 8),
          const Text('Your streak counts from this day.',
              style: TextStyle(fontSize: 13.5, color: DayOneColors.muted)),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days.map((d) {
                  final selected = _isSameDay(d, _startDate);
                  final isToday = _isSameDay(d, now);
                  return GestureDetector(
                    onTap: () => setState(() => _startDate = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? DayOneColors.terracotta
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekday(d),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : DayOneColors.muted)),
                          Text('${d.day}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : DayOneColors.ink)),
                          if (isToday)
                            Text('•',
                                style: TextStyle(
                                    fontSize: 10,
                                    height: 0.6,
                                    color: selected
                                        ? Colors.white
                                        : DayOneColors.terracotta)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pick the day you last had contact. Yesterday counts too — honesty keeps the streak real.',
            style: TextStyle(
                fontSize: 12.5, height: 1.5, color: DayOneColors.muted),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ page 3

  Widget _setupPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          const Text('STEP 2 OF 2',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 10),
          const Text('Who is this\njourney for?',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DayOneColors.ink,
                  height: 1.15)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _choiceCard(true, 'Me', "I'm healing")),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _choiceCard(false, 'A friend', 'Supporting them')),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily check-in reminders',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DayOneColors.ink)),
                        Text('One gentle nudge a day',
                            style: TextStyle(
                                fontSize: 12,
                                color: DayOneColors.muted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: AppState.instance.notificationsOn,
                    activeTrackColor: DayOneColors.sage,
                    onChanged: (v) =>
                        AppState.instance.setNotificationsOn(v),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: _finish,
              child: const Text('skip for now',
                  style: TextStyle(color: DayOneColors.muted)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _choiceCard(bool self, String title, String sub) {
    final selected = _forSelf == self;
    return GestureDetector(
      onTap: () => setState(() => _forSelf = self),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? DayOneColors.terracotta
                : DayOneColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? DayOneColors.terracotta
                        : DayOneColors.muted)),
            const SizedBox(height: 4),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11.5, color: DayOneColors.muted)),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekday(DateTime d) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];
}
