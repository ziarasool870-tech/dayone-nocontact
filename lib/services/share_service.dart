/// Milestone share cards: rendered on-device (no network), shared via the
/// system share sheet. This is the viral engine — cards are designed to be
/// posted to TikTok / Reels / Shorts.
///
/// Free art: warm cream + terracotta. Premium art (Pro): dark + gold.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// Per-milestone share messages.
const Map<int, String> milestoneMessages = {
  7: 'One week of choosing yourself.',
  14: 'Two weeks strong. The fog is lifting.',
  30: 'One month of choosing yourself.',
  60: 'Two months. Look how far you\'ve come.',
  90: '90 days. You\'re someone new now.',
};

/// The card widget itself. Rendered off-screen inside a [RepaintBoundary]
/// for capture; also previewed in the Milestones tab.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard(
      {super.key, required this.day, this.premium = false});

  final int day;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final message = milestoneMessages[day] ?? 'Keep going.';
    if (premium) return _premiumCard(day, message);
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: DayOneColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DayOneColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DAY ONE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: DayOneColors.terracotta)),
          const SizedBox(height: 12),
          Text('Day $day',
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: DayOneColors.ink)),
          const SizedBox(height: 10),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                DayOneColors.terracotta,
                Color(0xFFE8A07E)
              ]),
            ),
            alignment: Alignment.center,
            child: const Text('♥',
                style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: DayOneColors.ink)),
          const SizedBox(height: 18),
          const Text('No Contact · Day One',
              style: TextStyle(
                  fontSize: 11,
                  color: DayOneColors.muted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _premiumCard(int day, String message) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2A26), Color(0xFF4A3B2E)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DAY ONE · PRO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: DayOneColors.gold)),
          const SizedBox(height: 12),
          Text('Day $day',
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                DayOneColors.gold,
                Color(0xFFE8C89F)
              ]),
            ),
            alignment: Alignment.center,
            child: const Text('♥',
                style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: Colors.white)),
          const SizedBox(height: 18),
          const Text('No Contact · Day One',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  /// Renders [MilestoneCard] off-screen and shares the PNG.
  /// Must be called with a valid [BuildContext] (uses Overlay).
  Future<bool> shareMilestoneCard(
    BuildContext context, {
    required int day,
    required bool premium,
  }) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -1000,
        top: -1000,
        child: RepaintBoundary(
          key: key,
          child: MilestoneCard(day: day, premium: premium),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      // Let the off-screen widget lay out and paint.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return false;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return false;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/dayone-day$day.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Day $day of no contact. One day at a time. — Day One',
      ));
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } finally {
      entry.remove();
    }
  }
}
