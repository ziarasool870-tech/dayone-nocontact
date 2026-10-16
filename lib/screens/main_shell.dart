/// Main shell: 3-tab bottom nav (Home | Journal | Milestones) with the
/// persistent SOS floating button and the profile entry point.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';
import '../services/app_lock_service.dart';
import 'app_lock_screen.dart';
import 'home_screen.dart';
import 'journal_screen.dart';
import 'milestones_screen.dart';
import 'profile_screen.dart';
import 'sos_breath_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App lock session rule: re-lock when the app is no longer visible.
  /// `paused` only — `inactive` also fires for system dialogs (like the
  /// widget-pin prompt) that never leave the app, and those must NOT
  /// re-lock. On return, the PIN gate covers the app before content shows.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppLockService.instance.lock();
    } else if (state == AppLifecycleState.resumed) {
      _maybeShowGate();
    }
  }

  Future<void> _maybeShowGate() async {
    if (!mounted) return;
    await maybeShowAppLockGate(context);
  }

  void _openSos() {
    Navigator.of(context).push(
      FadeSlidePageRoute(child: const SosBreathScreen()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      FadeSlidePageRoute(child: const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      JournalScreen(),
      MilestonesScreen(),
    ];
    return Scaffold(
      appBar: _tab == 0
          ? AppBar(
              title: ListenableBuilder(
                listenable: AppState.instance,
                builder: (_, __) {
                  final name = AppState.instance.userName;
                  return Text(
                      name.isEmpty ? 'Day One' : 'Day One, $name');
                },
              ),
              actions: [
                IconButton(
                  onPressed: _openProfile,
                  icon: const CircleAvatar(
                    radius: 16,
                    backgroundColor: DayOneColors.terracottaSoft,
                    child: Icon(Icons.person,
                        size: 18,
                        color: DayOneColors.terracottaDeep),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: pages),
          // On the Journal tab the right-aligned "New entry" FAB would collide
          // with a centered pill on narrow phones — dock the pill left there
          // so the two never overlap (pill shares the FAB's 16dp baseline).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _tab == 1
                ? Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SosFab(onTap: _openSos),
                    ),
                  )
                : Center(child: SosFab(onTap: _openSos)),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_outlined),
              activeIcon: Icon(Icons.edit_note),
              label: 'Journal'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Milestones'),
        ],
      ),
    );
  }
}
