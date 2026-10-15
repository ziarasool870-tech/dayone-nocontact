/// Milestones tab: unlock gallery at Day 7/14/30/60/90, shareable cards,
/// and Pro-gated premium art. The viral engine lives here.
library;

import 'package:flutter/material.dart';

import '../domain/streak.dart' as streak_math;
import '../services/billing_service.dart';
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';
import 'paywall_screen.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  bool _sharing = false;

  Future<void> _share(int day, {required bool premium}) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await ShareService.instance.shareMilestoneCard(
        context,
        day: day,
        premium: premium,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openPaywall() {
    Navigator.of(context).push(
      FadeSlidePageRoute(child: const PaywallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milestones')),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [AppState.instance, BillingService.instance.uiState]),
        builder: (context, _) {
          final app = AppState.instance;
          final days = app.elapsedDays;
          final unlocked = streak_math.unlockedMilestones(days);
          final isPro = BillingService.instance.uiState.value.isPro;
          final next = streak_math.nextMilestone(days);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Every milestone is proof.\nShare how far you\'ve come.',
                  style: TextStyle(
                      fontSize: 16, height: 1.5, color: DayOneColors.muted),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: streak_math.milestoneDays.length,
                  itemBuilder: (context, i) {
                    final m = streak_math.milestoneDays[i];
                    final isUnlocked = unlocked.contains(m);
                    final isNext = m == next;
                    return _tile(m, isUnlocked, isNext);
                  },
                ),
                const SizedBox(height: 20),
                // Premium art packs — Pro gated.
                Row(
                  children: [
                    const Expanded(
                      child: Text('Premium art packs',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DayOneColors.goldSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: DayOneColors.goldBorder),
                      ),
                      child: const Text('PRO',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A5A1E))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dark & gold editions of every card. Made to be posted.',
                  style: TextStyle(
                      fontSize: 14.5, color: DayOneColors.muted),
                ),
                const SizedBox(height: 12),
                if (!isPro)
                  GestureDetector(
                    onTap: _openPaywall,
                    child: const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Unlock premium art',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text(
                                      'Plus the 90-day program and letter vault.',
                                      style: TextStyle(
                                          fontSize: 14.5,
                                          color: DayOneColors.muted)),
                                ],
                              ),
                            ),
                            Icon(Icons.lock_outline,
                                color: DayOneColors.gold),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...streak_math.milestoneDays
                      .where((m) => unlocked.contains(m))
                      .map((m) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: MilestoneCard(day: m, premium: true),
                          )),
                if (isPro &&
                    streak_math.milestoneDays
                        .where((m) => unlocked.contains(m))
                        .isEmpty)
                  const Text(
                    'Unlock milestones to preview premium art here.',
                    style: TextStyle(
                        fontSize: 14.5, color: DayOneColors.muted),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(int day, bool unlocked, bool isNext) {
    final bg = unlocked
        ? DayOneColors.goldSoft
        : isNext
            ? DayOneColors.terracottaPale
            : DayOneColors.lockedBg;
    final border = unlocked
        ? DayOneColors.goldBorder
        : isNext
            ? DayOneColors.terracotta
            : DayOneColors.lockedBorder;
    final fg = unlocked
        ? const Color(0xFF8A5A1E)
        : isNext
            ? DayOneColors.terracottaDeep
            : DayOneColors.lockedText;
    return GestureDetector(
      onTap: unlocked ? () => _preview(day) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: border, width: isNext ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text('★', style: TextStyle(fontSize: 24, color: fg))
            else if (isNext)
              Text('◷', style: TextStyle(fontSize: 24, color: fg))
            else
              Icon(Icons.lock_outline, size: 24, color: fg),
            const SizedBox(height: 8),
            Text('Day $day',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: fg)),
            const SizedBox(height: 4),
            Text(
              unlocked
                  ? 'Unlocked · tap to share'
                  : isNext
                      ? '${day - streak_math.displayDay(AppState.instance.elapsedDays)} days to go'
                      : 'Locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }

  void _preview(int day) {
    final isPro = BillingService.instance.uiState.value.isPro;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: DayOneColors.line,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            MilestoneCard(day: day, premium: false),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _sharing ? null : () => _share(day, premium: false),
                icon: _sharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share, size: 18),
                label: Text(_sharing ? 'Preparing…' : 'Share this card'),
              ),
            ),
            if (isPro) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sharing
                      ? null
                      : () => _share(day, premium: true),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Share premium art'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
