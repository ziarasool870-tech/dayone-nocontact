/// Central app state for Day One: No Contact.
///
/// A single [ChangeNotifier] singleton. Widgets rebuild via
/// [ListenableBuilder]. All persistence goes through [PrefsService] and
/// [DayOneDatabase]; streak math stays in the pure [domain] module.
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/database.dart';
import '../data/prefs.dart';
import '../domain/streak.dart' as streak_math;
import '../services/billing_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  bool ready = false;
  bool _billingListening = false;

  int? streakStartMs;
  int longestDays = 0;
  int totalCleanDays = 0;
  String userName = '';
  bool notificationsOn = true;

  /// Transient (never persisted): the OS is currently refusing to post
  /// notifications (permission denied/revoked). While true, the UI must
  /// show "Off — permission needed" and never a fake "On".
  bool notificationsBlocked = false;
  int reminderHour = 20;
  int reminderMinute = 0;

  /// Milestone days unlocked but not yet celebrated in this session.
  final List<int> pendingCelebrations = [];

  int get elapsedDays => streakStartMs == null
      ? 0
      : streak_math.daysElapsed(
          streakStartMs!, DateTime.now().millisecondsSinceEpoch);

  bool get hasStreak => streakStartMs != null;

  bool get isPro => BillingService.instance.uiState.value.isPro;

  Future<void> init() async {
    final prefs = await PrefsService.instance();
    await DayOneDatabase.instance.database; // ensure schema exists
    await BillingService.instance.init();

    // A data wipe can re-run init(): never carry celebrations
    // from a deleted life into the new one.
    pendingCelebrations.clear();

    streakStartMs = prefs.streakStartMs;
    longestDays = prefs.longestDays;
    totalCleanDays = prefs.totalCleanDays;
    userName = prefs.userName;
    notificationsOn = prefs.notificationsOn;
    reminderHour = prefs.reminderHour;
    reminderMinute = prefs.reminderMinute;
    // Keep the home widget honest on every launch and after imports:
    // without this, an imported backup's streak wouldn't reach the
    // widget until the next 30-minute system tick.
    await _pushWidget();

    // Load history into longest/total if prefs are empty (fresh import).
    if (streakStartMs != null && (longestDays == 0 && totalCleanDays == 0)) {
      final history = await DayOneDatabase.instance.allStreakHistory();
      for (final row in history) {
        final d = (row['days'] as num?)?.toInt() ?? 0;
        if (d > longestDays) longestDays = d;
        totalCleanDays += d;
      }
      await prefs.setLongestDays(longestDays);
      await prefs.setTotalCleanDays(totalCleanDays);
    }

    _detectNewMilestones(firstRun: true);

    // Honest reminder state: if the OS will not let us post, say so
    // instead of showing a fake "On". Never nags with a dialog here.
    notificationsBlocked = false;
    if (notificationsOn) {
      notificationsBlocked = !await NotificationService.instance
          .rescheduleQuietly(
              hour: prefs.reminderHour, minute: prefs.reminderMinute);
    }
    ready = true;
    notifyListeners();
    // init() can run again (e.g. after a backup import) — never add
    // the billing listener twice.
    if (!_billingListening) {
      BillingService.instance.uiState.addListener(_onBillingChanged);
      _billingListening = true;
    }
  }

  void _onBillingChanged() => notifyListeners();

  /// Detects newly unlocked milestones vs. what the user has seen.
  /// When [firstRun] is false, unseen unlocks go to [pendingCelebrations].
  Future<void> _detectNewMilestones({bool firstRun = false}) async {
    if (streakStartMs == null) return;
    final prefs = await PrefsService.instance();
    final seen = prefs.milestonesSeen;
    final unlocked = streak_math.unlockedMilestones(elapsedDays);
    var changed = false;
    for (final m in unlocked) {
      if (!seen.contains(m)) {
        await prefs.markMilestoneSeen(m);
        changed = true;
        if (!firstRun) {
          pendingCelebrations.add(m);
          await NotificationService.instance.notifyMilestone(m);
        }
      }
    }
    if (changed) notifyListeners();
  }

  /// Call when Home becomes visible to catch unlocks.
  Future<void> refreshMilestones() => _detectNewMilestones();

  void consumeCelebrations() {
    pendingCelebrations.clear();
    notifyListeners();
  }

  Future<void> setStartDate(DateTime date) async {
    final prefs = await PrefsService.instance();
    // Day-0 starts at local midnight of the chosen day.
    final start =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    await prefs.setStreakStartMs(start);
    streakStartMs = start;
    // Backdated starts (e.g. 6 months ago) already earned milestones:
    // mark them seen SILENTLY — they show unlocked in the gallery,
    // but no notification burst / celebration spam on day one.
    await _detectNewMilestones(firstRun: true);
    await _pushWidget();
    notifyListeners();
  }

  /// Shame-free relapse: counter restarts, history is kept.
  Future<void> relapse() async {
    if (streakStartMs == null) return;
    final prefs = await PrefsService.instance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = streak_math.StreakState(
      currentStartMs: streakStartMs!,
      longestDays: longestDays,
      totalCleanDays: totalCleanDays,
      history: (await DayOneDatabase.instance.allStreakHistory())
          .map(streak_math.StreakRecord.fromMap)
          .toList(),
    );
    final next = streak_math.recordRelapse(state, now);
    // Persist the newly banked record (the latest one).
    if (next.history.length > state.history.length) {
      final rec = next.history.last;
      await DayOneDatabase.instance.insertStreakRecord(
        startMs: rec.startMs,
        endMs: rec.endMs,
        days: rec.days,
      );
    }
    await prefs.setStreakStartMs(next.currentStartMs);
    await prefs.setLongestDays(next.longestDays);
    await prefs.setTotalCleanDays(next.totalCleanDays);
    // The 90-day program follows the same journey: a new streak means
    // a new Day 1. Completed tasks are cleared, kindly — the copy on the
    // program screen frames this as "your tasks waited for you".
    await prefs.setProgramDoneDays({});
    streakStartMs = next.currentStartMs;
    longestDays = next.longestDays;
    totalCleanDays = next.totalCleanDays;
    await _pushWidget();
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    final prefs = await PrefsService.instance();
    await prefs.setUserName(name.trim());
    userName = name.trim();
    notifyListeners();
  }

  Future<void> setNotificationsOn(bool on) async {
    final prefs = await PrefsService.instance();
    if (!on) {
      await prefs.setNotificationsOn(false);
      notificationsOn = false;
      notificationsBlocked = false;
      notifyListeners();
      try {
        await NotificationService.instance.cancelDailyReminder();
      } catch (_) {
        // Best-effort.
      }
      return;
    }
    // Turning ON: permission first — the toggle must never claim "On"
    // when the OS will silently drop every reminder. The system dialog
    // (Android 13+) is fine here: the user just asked for reminders.
    final scheduled = await NotificationService.instance.scheduleDailyReminder(
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
    );
    notificationsBlocked = !scheduled;
    // Persist the truth, not the wish.
    await prefs.setNotificationsOn(scheduled);
    notificationsOn = scheduled;
    notifyListeners();
  }

  /// Persists the daily reminder time and reschedules the notification.
  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await PrefsService.instance();
    await prefs.setReminderTime(hour, minute);
    reminderHour = hour;
    reminderMinute = minute;
    notifyListeners();
    if (notificationsOn) {
      // Quiet path: never nag with a dialog on a time change. If the
      // permission went away, say so honestly instead of faking "On".
      final ok = await NotificationService.instance.rescheduleQuietly(
        hour: hour,
        minute: minute,
      );
      if (!ok) {
        notificationsBlocked = true;
        notifyListeners();
      }
    }
  }

  /// Pushes the current streak to the Android home-screen widget.
  Future<void> _pushWidget() async {
    try {
      await HomeWidget.saveWidgetData<int>(
          'streak_start_ms', streakStartMs ?? 0);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.dayone.nocontact.DayOneWidgetProvider',
      );
    } catch (_) {
      // Widget is best-effort; the app must never crash over it.
    }
  }

  /// yyyy-MM-dd for today (local).
  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}
