/// Onboarding: welcome → start date → quick setup. Under 30 seconds.
/// No quiz fatigue, no account, no paywall before value.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;
  // Guards against double-taps skipping a page: _page only updates via
  // onPageChanged, which lags the 320ms animation.
  bool _animating = false;
  DateTime _startDate = DateTime.now();
  // Month currently shown in the start-date calendar grid.
  late DateTime _shownMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  void _next() {
    if (_animating) return;
    if (_page < 2) {
      _animating = true;
      _pager
          .nextPage(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _animating = false);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_animating || _page <= 0) return;
    _animating = true;
    _pager
        .previousPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _animating = false);
  }

  /// Calm back chevron for pages 2–3 — a wrong date should never
  /// feel like a trap.
  Widget _backRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: _back,
        tooltip: 'Back',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.arrow_back, size: 22, color: DayOneColors.muted),
      ),
    );
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
    // System back goes to the previous onboarding page instead of
    // killing the flow (page 1 may still exit).
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _back();
      },
      child: Scaffold(
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
                  child: PressScale(
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(_page == 2 ? 'Enter Day One' : 'Continue'),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    // Scroll-safe on short screens / large fonts: content centers on tall
    // phones, scrolls instead of overflowing on small ones.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BreathingAppIcon(),
          const SizedBox(height: 26),
          const Text('DAY ONE',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 8),
          const Text('No Contact',
              style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DayOneColors.ink)),
          const SizedBox(height: 14),
          const Text(
            'Your breakup recovery companion.\nOne day at a time.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 17, height: 1.5, color: DayOneColors.muted),
          ),
          const SizedBox(height: 18),
          const Text('Free forever where it matters.',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: DayOneColors.terracottaDeep)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ------------------------------------------------------------ page 2

  Widget _datePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _backRow(),
          const SizedBox(height: 12),
          const Text('STEP 1 OF 2',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 10),
          const Text('When did\nno contact start?',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: DayOneColors.ink,
                  height: 1.15)),
          const SizedBox(height: 8),
          const Text('Your streak counts from this day.',
              style: TextStyle(fontSize: 15.5, color: DayOneColors.muted)),
          const SizedBox(height: 4),
          const Text('This is the day you chose yourself.',
              style: TextStyle(
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  color: DayOneColors.terracottaDeep)),
          const SizedBox(height: 16),
          _quickChips(),
          const SizedBox(height: 14),
          _monthGrid(),
          const SizedBox(height: 12),
          _previewLine(),
          const SizedBox(height: 12),
          const Text(
            'Pick the day you last had contact. Yesterday counts too — honesty keeps the streak real.',
            style: TextStyle(
                fontSize: 14.5, height: 1.5, color: DayOneColors.muted),
          ),
          const SizedBox(height: 6),
          const Text(
            'Not sure? Pick your best guess — you can change it later in Profile.',
            style: TextStyle(
                fontSize: 14.5, height: 1.5, color: DayOneColors.muted),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  /// Quick-pick chips above the grid: Today / Yesterday / A week ago.
  /// Single-select — the chip matching [_startDate] is active; tapping a
  /// chip sets the date (and jumps the grid to that month).
  Widget _quickChips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final options = <String, DateTime>{
      'Today': today,
      'Yesterday': today.subtract(const Duration(days: 1)),
      'A week ago': today.subtract(const Duration(days: 7)),
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries.map((e) {
        final active = _isSameDay(e.value, _startDate);
        return GestureDetector(
          onTap: () => setState(() {
            _startDate = e.value;
            _shownMonth = DateTime(e.value.year, e.value.month);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: active ? DayOneColors.terracotta : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: active
                    ? DayOneColors.terracotta
                    : DayOneColors.cardBorder,
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: DayOneColors.terracotta.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(e.key,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : DayOneColors.muted)),
          ),
        );
      }).toList(),
    );
  }

  /// Live preview under the grid: "♥ 16 October 2026 · Day 1 starts here".
  Widget _previewLine() {
    final d = _startDate;
    final label = '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: DayOneColors.terracottaSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite,
              size: 14, color: DayOneColors.terracottaDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label · Day 1 starts here',
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: DayOneColors.ink)),
          ),
        ],
      ),
    );
  }

  /// Full-month calendar grid for picking the streak start day.
  /// Back to Jan 2020 (matches Profile's start-date picker),
  /// forward to the current month. Future days disabled.
  Widget _monthGrid() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final y = _shownMonth.year;
    final m = _shownMonth.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final leadBlanks = DateTime(y, m, 1).weekday - 1; // Monday-first
    final minMonth = DateTime(2020, 1);
    final maxMonth = DateTime(now.year, now.month);
    final canGoBack = DateTime(y, m).isAfter(minMonth);
    final canGoForward = DateTime(y, m).isBefore(maxMonth);

    final cells = <Widget>[];
    for (var i = 0; i < leadBlanks; i++) {
      cells.add(const SizedBox(height: 40));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(y, m, d);
      final selected = _isSameDay(date, _startDate);
      final isToday = _isSameDay(date, today);
      final disabled = date.isAfter(today);
      cells.add(
        GestureDetector(
          onTap: disabled ? null : () => setState(() => _startDate = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            decoration: BoxDecoration(
              color: selected ? DayOneColors.terracotta : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: DayOneColors.terracotta.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: selected
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$d',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(width: 3),
                        const Icon(Icons.favorite,
                            size: 10, color: Colors.white),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$d',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: disabled
                                      ? DayOneColors.faint
                                      : DayOneColors.ink)),
                        ),
                      ),
                      if (isToday)
                        const Text('•',
                            style: TextStyle(
                                fontSize: 9,
                                height: 0.5,
                                color: DayOneColors.terracotta)),
                    ],
                  ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canGoBack
                      ? () => setState(() => _shownMonth = DateTime(y, m - 1))
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: DayOneColors.terracotta,
                  disabledColor: DayOneColors.faint,
                ),
                Expanded(
                  child: Center(
                    child: Text('${_monthNames[m - 1]} $y',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: DayOneColors.ink)),
                  ),
                ),
                IconButton(
                  onPressed: canGoForward
                      ? () => setState(() => _shownMonth = DateTime(y, m + 1))
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: DayOneColors.terracotta,
                  disabledColor: DayOneColors.faint,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(w,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: DayOneColors.muted)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ page 3

  Widget _setupPage() {
    // Scroll-safe on short screens / large fonts: spacers distribute
    // extra room on tall phones, content scrolls on small ones.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _backRow(),
                const SizedBox(height: 12),
                const Text('STEP 2 OF 2',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: DayOneColors.terracotta)),
                const SizedBox(height: 10),
                const Text('A gentle daily\nnudge',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: DayOneColors.ink,
                        height: 1.15)),
                const SizedBox(height: 10),
                const Text(
                  'One soft reminder to check in with your heart.',
                  style: TextStyle(
                      fontSize: 16, height: 1.5, color: DayOneColors.muted),
                ),
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily check-in reminders',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: DayOneColors.ink)),
                              Text('One gentle nudge a day',
                                  style: TextStyle(
                                      fontSize: 14, color: DayOneColors.muted)),
                            ],
                          ),
                        ),
                        // ListenableBuilder so the toggle flips visually the
                        // moment it's tapped (this screen doesn't otherwise
                        // rebuild on AppState changes).
                        ListenableBuilder(
                          listenable: AppState.instance,
                          builder: (context, _) => Switch(
                            value: AppState.instance.notificationsOn,
                            activeTrackColor: DayOneColors.sage,
                            onChanged: (v) =>
                                AppState.instance.setNotificationsOn(v),
                          ),
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
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The real Day One app icon, gently breathing — the first impression
/// should feel alive and warm, not static.
class BreathingAppIcon extends StatefulWidget {
  const BreathingAppIcon({super.key});

  @override
  State<BreathingAppIcon> createState() => _BreathingAppIconState();
}

class _BreathingAppIconState extends State<BreathingAppIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1.0 + 0.07 * Curves.easeInOut.transform(_ctrl.value);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: DayOneColors.terracotta.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 124,
            height: 124,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
