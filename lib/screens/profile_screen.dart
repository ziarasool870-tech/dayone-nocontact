/// Profile tab: identity, stats, settings, data safety, info, Pro upsell.
library;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/content.dart';
import '../data/database.dart';
import '../data/prefs.dart';
import '../domain/streak.dart' as streak_math;
import '../services/backup_service.dart';
import '../services/billing_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/widget_pin_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'program_screen.dart';
import 'vault_pin_screen.dart';
import 'vault_screen.dart';

/// Support inbox for the "Send feedback" row.
const kSupportEmail = 'support@dayonenocontact.app';

/// Pure summary text for the Notifications profile row (unit-testable).
///
/// 'Off — permission needed' wins over everything: the row must never
/// claim "On" when the OS will silently drop every reminder.
String reminderSummaryText({
  required bool notificationsOn,
  required bool notificationsBlocked,
  required String timeLabel,
}) {
  if (notificationsBlocked) return 'Off — permission needed';
  if (!notificationsOn) return 'Off';
  return 'On · $timeLabel';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _journalCount = 0;
  int _milestonesUnlocked = 0;
  double _checkInRate = 0;
  bool _busyBackup = false;
  String _widgetTheme = 'cream';

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWidgetTheme();
    // Keep journal/milestone counts fresh: start-date edits and
    // relapses (from the Home tab) change the numbers while this
    // screen is kept alive in the IndexedStack.
    AppState.instance.addListener(_loadStats);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_loadStats);
    super.dispose();
  }

  /// Reads the widget theme previously chosen via home_widget data.
  Future<void> _loadWidgetTheme() async {
    try {
      final theme = await HomeWidget.getWidgetData<String>(
        'widget_theme',
        defaultValue: 'cream',
      );
      if (mounted && theme != null) {
        setState(() => _widgetTheme = theme);
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  String get _widgetThemeLabel =>
      _widgetTheme == 'midnight' ? 'Midnight' : 'Cream';

  /// Theme picker: Midnight is Pro-gated; free users see the locked state.
  void _widgetThemeSheet(bool isPro) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        // Scrollable: theme options + pin button must never clip
        // on small screens or large font sizes.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Widget theme',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('How your home-screen widget looks.',
                style: TextStyle(fontSize: 15, color: DayOneColors.muted)),
            const SizedBox(height: 14),
            _themeOption(
              title: 'Cream',
              sub: 'Warm and light',
              value: 'cream',
              locked: false,
              isPro: isPro,
            ),
            _themeOption(
              title: 'Midnight',
              sub: 'Dark with gold accents',
              value: 'midnight',
              locked: !isPro,
              isPro: isPro,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _addWidgetToHomeScreen(ctx),
                icon: const Icon(Icons.add_to_home_screen_rounded, size: 20),
                label: const Text('Add widget to Home screen'),
                style: FilledButton.styleFrom(
                  backgroundColor: DayOneColors.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'One tap — your phone will ask where to place it.',
              style: TextStyle(fontSize: 13.5, color: DayOneColors.muted),
            ),
          ],
          ),
        ),
      ),
    );
  }

  /// One-tap widget install. Uses Android's pin-widget request; when the
  /// launcher doesn't support it, shows the manual steps instead.
  Future<void> _addWidgetToHomeScreen(BuildContext sheetContext) async {
    final pinned = await WidgetPinService().requestPin();
    if (!mounted) return;
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    if (pinned) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add the widget yourself'),
        content: const Text(
          'Your phone asked us not to place it automatically. It takes a moment:\n\n1. Pinch in on your Home screen\n2. Tap Widgets\n3. Find Day One and drag it where you like',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required String title,
    required String sub,
    required String value,
    required bool locked,
    required bool isPro,
  }) {
    final selected = _widgetTheme == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            if (locked) {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                FadeSlidePageRoute(child: const PaywallScreen()),
              );
              return;
            }
            try {
              await HomeWidget.saveWidgetData<String>('widget_theme', value);
              await HomeWidget.updateWidget(
                qualifiedAndroidName:
                    'com.dayone.nocontact.DayOneWidgetProvider',
              );
            } catch (_) {
              // Best-effort only.
            }
            if (mounted) {
              setState(() => _widgetTheme = value);
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: value == 'midnight'
                        ? const Color(0xFF23201C)
                        : DayOneColors.cream,
                    border: Border.all(color: DayOneColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('12',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: value == 'midnight'
                              ? const Color(0xFFE8C89F)
                              : DayOneColors.terracotta)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16.5, fontWeight: FontWeight.w700)),
                          if (locked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: DayOneColors.goldSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('PRO',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8A5A1E))),
                            ),
                          ],
                        ],
                      ),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 14.5, color: DayOneColors.muted)),
                    ],
                  ),
                ),
                if (locked)
                  const Icon(Icons.lock_outline,
                      size: 20, color: DayOneColors.faint)
                else if (selected)
                  const Icon(Icons.check_circle,
                      size: 20, color: DayOneColors.sage)
                else
                  const Icon(Icons.circle_outlined,
                      size: 20, color: DayOneColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadStats() async {
    final db = DayOneDatabase.instance;
    final jc = await db.journalCount();
    final rate = await db.checkInRate();
    if (!mounted) return;
    // Milestone count is display-day based (Day 1 = start day).
    final days = AppState.instance.elapsedDays;
    setState(() {
      _journalCount = jc;
      _checkInRate = rate;
      _milestonesUnlocked = streak_math.unlockedMilestones(days).length;
    });
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: AppState.instance.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        title: const Text('Your name',
            style: TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: DayOneColors.ink),
          decoration: const InputDecoration(
            hintText: 'What should we call you?',
            hintStyle: TextStyle(color: DayOneColors.muted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (name != null) {
      await AppState.instance.setUserName(name);
    }
  }

  Future<void> _editStartDate() async {
    final current = AppState.instance.streakStartMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(AppState.instance.streakStartMs!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'When did no contact start?',
    );
    if (picked != null) {
      await AppState.instance.setStartDate(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start date updated.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _askPassphrase(
      {required Future<String> Function(String) action,
      required String title,
      required String cta}) async {
    final ctrl = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        title: Text(title,
            style: const TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your backup is encrypted with this passphrase. Don\'t lose it — we can\'t recover it for you.',
              style: TextStyle(fontSize: 15, color: DayOneColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: DayOneColors.ink),
              decoration: const InputDecoration(
                hintText: 'Backup passphrase',
                hintStyle: TextStyle(color: DayOneColors.muted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child:
                Text(cta, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (pass == null || pass.isEmpty) return;
    setState(() => _busyBackup = true);
    try {
      final msg = await action(pass);
      // Import returns '' on success (it shows its own result) —
      // never show a blank snackbar.
      if (mounted && msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4)),
        );
        _loadStats();
      } else if (mounted) {
        _loadStats();
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _confirmImport(String pass) async {
    // Capture before any async gap.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        scrollable: true,
        title: const Text('Replace current data?',
            style: TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: const Text(
            'Importing a backup wipes what\'s on this phone now and restores the backup instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace & import',
                style: TextStyle(color: DayOneColors.sos)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final msg = await BackupService.instance.importFromPicker(pass);
      if (!mounted) return;
      // Reload everything after an import.
      await AppState.instance.init();
      messenger.showSnackBar(
        SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4)),
      );
    }
  }

  /// Opens a Pro-gated feature: the feature itself for Pro users,
  /// the paywall for everyone else.
  void _openProFeature(bool isPro, Widget feature) {
    Navigator.of(context).push(
      FadeSlidePageRoute(child: isPro ? feature : const PaywallScreen()),
    );
  }

  void _whySheet() {    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why no contact works',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Commonly shared self-care wisdom — not medical advice.',
                  style: TextStyle(fontSize: 14.5, color: DayOneColors.muted)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  itemCount: whyNoContactWorks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = whyNoContactWorks[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title']!,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(item['body']!,
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.55,
                                    color: DayOneColors.muted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _disclaimerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A gentle note',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(disclaimerText,
                style: TextStyle(
                    fontSize: 16, height: 1.6, color: DayOneColors.muted)),
            const SizedBox(height: 12),
            Builder(builder: (ctx) {
              final entry = resolveCrisisHelpline(
                WidgetsBinding.instance.platformDispatcher.locale.countryCode,
              );
              // Safety: uncovered countries get ONLY the international
              // directory — never a foreign number. Tappable, like the
              // SOS crisis card.
              final hasNumber = entry != null;
              return GestureDetector(
                onTap: () => hasNumber
                    ? launchUrl(Uri(scheme: 'tel', path: entry['dial']))
                    : launchUrl(Uri.parse(crisisFallbackUrl),
                        mode: LaunchMode.externalApplication),
                child: Text(
                    hasNumber
                        ? '${entry['prefix']}${entry['number']}'
                        : 'Find a helpline in your country →',
                    style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: DayOneColors.terracottaDeep,
                        decoration: TextDecoration.underline)),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// App version shown in the About sheet. Keep in sync with pubspec.yaml.
  static const _appVersion = '1.0.9';

  /// About sheet: studio credit, mission line, version. No personal names,
  /// no location — English only.
  void _aboutSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Day One: No Contact',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('Made with care by Daybreak Studio',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DayOneColors.ink)),
            const SizedBox(height: 8),
            const Text(
                'For anyone healing, one day at a time. Your words never leave your phone.',
                style: TextStyle(
                    fontSize: 15.5, height: 1.6, color: DayOneColors.muted)),
            const SizedBox(height: 12),
            Text('Version $_appVersion',
                style: const TextStyle(
                    fontSize: 13.5, color: DayOneColors.faint)),
          ],
        ),
      ),
    );
  }

  /// "On · 8:00 PM" / "Off" / "Off — permission needed" for the
  /// notifications row. Never claims "On" when reminders cannot fire.
  String _reminderSummary(AppState app) {
    final t = TimeOfDay(hour: app.reminderHour, minute: app.reminderMinute)
        .format(context);
    return reminderSummaryText(
      notificationsOn: app.notificationsOn,
      notificationsBlocked: app.notificationsBlocked,
      timeLabel: t,
    );
  }

  /// Gentle reminder settings: on/off toggle plus the daily time picker.
  void _reminderSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily reminders',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('One gentle nudge a day.',
                style: TextStyle(fontSize: 15, color: DayOneColors.muted)),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                final app = AppState.instance;
                // Effective state: a blocked permission is honestly "off".
                final on = app.notificationsOn && !app.notificationsBlocked;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Reminders',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        Switch(
                          value: on,
                          activeTrackColor: DayOneColors.sage,
                          onChanged: (v) => app.setNotificationsOn(v),
                        ),
                      ],
                    ),
                    if (app.notificationsBlocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          'Permission was denied — flip Reminders on to allow notifications.',
                          style: TextStyle(
                              fontSize: 13.5, color: DayOneColors.muted),
                        ),
                      ),
                    const Divider(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: on ? () => _pickReminderTime(ctx) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Reminder time',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: on
                                          ? DayOneColors.ink
                                          : DayOneColors.faint)),
                            ),
                            Text(
                              TimeOfDay(
                                      hour: app.reminderHour,
                                      minute: app.reminderMinute)
                                  .format(context),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: on
                                      ? DayOneColors.terracottaDeep
                                      : DayOneColors.faint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderTime(BuildContext ctx) async {
    final app = AppState.instance;
    final picked = await showTimePicker(
      context: ctx,
      initialTime:
          TimeOfDay(hour: app.reminderHour, minute: app.reminderMinute),
      helpText: 'When should we nudge you?',
    );
    if (picked != null) {
      await app.setReminderTime(picked.hour, picked.minute);
    }
  }

  /// Opens the email app addressed to support, with a prefilled subject.
  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      queryParameters: {'subject': 'Day One feedback'},
    );
    final ok = await launchUrl(uri);
    // No email app installed: say so gently, with the address in reach.
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No email app found — you can write to us at $kSupportEmail.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Honest, calm data deletion: confirm → wipe the database and all
  /// prefs → reset the widget and reminder → start over at onboarding.
  Future<void> _confirmDeleteData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        scrollable: true,
        title: const Text('Delete everything?',
            style: TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: const Text(
          'This permanently removes your journal, check-ins, streak history, and settings from this phone. There\'s no undo — your data never leaves this device, so we can\'t recover it.\n\nIf you\'re hurting right now, consider keeping an encrypted backup first (Export backup above).',
          style:
              TextStyle(fontSize: 15, height: 1.55, color: DayOneColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep my data')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything',
                style: TextStyle(color: DayOneColors.sos)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Wipe everything: database rows, all preferences.
    await DayOneDatabase.instance.wipeAll();
    final prefs = await PrefsService.instance();
    // A purchase is not "my data" — a paying user keeps Pro through
    // the wipe (their words are deleted, their purchase is not).
    final wasPro = prefs.isPro;
    final proId = prefs.proProductId;
    await prefs.clearAll();
    if (wasPro) await prefs.setPro(true, productId: proId);
    // Cancel the stale pre-wipe reminder BEFORE init(), so init()
    // re-schedules exactly like a fresh install and the onboarding
    // toggle tells the truth.
    await NotificationService.instance.cancelDailyReminder();
    // Reset in-memory state (init re-reads the now-empty prefs).
    await AppState.instance.init();
    // Leave no widget streak or theme behind for a deleted life.
    try {
      await HomeWidget.saveWidgetData<int>('streak_start_ms', 0);
      await HomeWidget.saveWidgetData<String>('widget_theme', 'cream');
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.dayone.nocontact.DayOneWidgetProvider',
      );
    } catch (_) {
      // Widget is best-effort.
    }

    if (!mounted) return;
    // Start over, like a fresh install.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (ctx) => OnboardingScreen(
          onFinished: () async {
            final p = await PrefsService.instance();
            await p.setOnboardingDone(true);
            if (ctx.mounted) {
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShell()),
                (r) => false,
              );
            }
          },
        ),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [AppState.instance, BillingService.instance.uiState]),
        builder: (context, _) {
          final app = AppState.instance;
          final isPro = BillingService.instance.uiState.value.isPro;
          final name = app.userName.isEmpty ? 'Friend' : app.userName;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          DayOneColors.terracotta,
                          Color(0xFFE8A07E)
                        ]),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(
                            isPro
                                ? 'Day One Pro'
                                : 'Healing since ${app.streakStartMs == null ? '—' : _fmtDate(app.streakStartMs!)}',
                            style: const TextStyle(
                                fontSize: 14.5, color: DayOneColors.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: _editName, child: const Text('Edit')),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        // Expanded + scale-down text: five stats share the
                        // width evenly and long labels ("Milestones") shrink
                        // slightly on small screens / large fonts instead of
                        // overflowing.
                        Expanded(
                            child: _stat(
                                '${streak_math.displayDay(app.elapsedDays)}',
                                'Current')),
                        Expanded(
                            child: _stat(
                                app.longestDays == 0
                                    ? '0'
                                    : '${app.longestDays + 1}',
                                'Longest')),
                        Expanded(
                            child: _stat('${(_checkInRate * 100).round()}%',
                                'Check-ins')),
                        Expanded(child: _stat('$_journalCount', 'Entries')),
                        Expanded(
                            child: _stat('$_milestonesUnlocked', 'Milestones')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Pro banner / status
                if (!isPro)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        FadeSlidePageRoute(child: const PaywallScreen()),
                      );
                    },
                    child: Card(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(colors: [
                            DayOneColors.terracotta,
                            DayOneColors.terracottaDeep
                          ]),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Day One Pro',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                  SizedBox(height: 4),
                                  Text(
                                      '90-day program · letter vault · premium art',
                                      style: TextStyle(
                                          fontSize: 14.5,
                                          color: Colors.white70)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: DayOneColors.gold),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                'Day One Pro active — thank you for supporting your own healing.',
                                style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Healing',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DayOneColors.muted)),
                const SizedBox(height: 8),
                _row('90-day program', 'A 2-minute healing task a day',
                    onTap: () => _openProFeature(
                        isPro, const ProgramScreen())),
                _row('Letter vault', 'Write what you\'ll never send',
                    onTap: () => ensureVaultUnlocked(
                          context,
                          isPro: isPro,
                          vault: const VaultScreen(),
                        )),
                const VaultPinRow(),
                const SizedBox(height: 16),
                const Text('Settings',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DayOneColors.muted)),
                const SizedBox(height: 8),
                _row('Start date', _fmtDate(app.streakStartMs),
                    onTap: _editStartDate),
                _row('Notifications', _reminderSummary(app),
                    onTap: _reminderSheet),
                _row('Widget theme', _widgetThemeLabel,
                    onTap: () => _widgetThemeSheet(isPro)),
                _row('Share Day One', 'Tell a friend who needs this',
                    onTap: () => SharePlus.instance.share(ShareParams(
                        text:
                            'I\'m using Day One: No Contact to heal, one day at a time.\n$kPlayStoreUrl'))),
                const SizedBox(height: 16),
                const Text('Your data',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DayOneColors.muted)),
                const SizedBox(height: 8),
                // Gentle, one-time inline explainer — never a popup.
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            color: DayOneColors.sage, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Protect your streak',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text(
                                'Your journal and streak are backed up automatically with your Android backup. For extra safety, keep an encrypted copy with Export backup below — your words never leave this phone unless you move them.',
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: DayOneColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _row('Export backup',
                    _busyBackup ? 'Working…' : 'Encrypted file you keep',
                    onTap: _busyBackup
                        ? null
                        : () => _askPassphrase(
                              title: 'Export backup',
                              cta: 'Export',
                              action: (pass) async {
                                final ok = await BackupService.instance
                                    .exportWithShareSheet(pass);
                                return ok
                                    ? 'Backup shared. Keep it somewhere safe.'
                                    : 'Export cancelled.';
                              },
                            )),
                _row('Import backup',
                    _busyBackup ? 'Working…' : 'Restore from a backup file',
                    onTap: _busyBackup
                        ? null
                        : () => _askPassphrase(
                              title: 'Import backup',
                              cta: 'Continue',
                              action: (pass) async {
                                await _confirmImport(pass);
                                return '';
                              },
                            )),
                _row('Delete my data', 'Remove everything from this phone',
                    destructive: true, onTap: _confirmDeleteData),
                const SizedBox(height: 16),
                const Text('About',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DayOneColors.muted)),
                const SizedBox(height: 8),
                _row('Why no contact works', '', onTap: _whySheet),
                _row('A gentle note (disclaimer)', '', onTap: _disclaimerSheet),
                _row('Send feedback', 'Tell us what\'s helping, or what hurts',
                    onTap: _sendFeedback),
                _row('About', 'Made with care by Daybreak Studio',
                    onTap: _aboutSheet),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Day One is a self-care companion,\nnot a therapist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: DayOneColors.faint, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: DayOneColors.muted)),
        ),
      ],
    );
  }

  Widget _row(String title, String sub,
      {VoidCallback? onTap, bool destructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: destructive
                                  ? DayOneColors.sos
                                  : DayOneColors.ink)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 14, color: DayOneColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: DayOneColors.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
