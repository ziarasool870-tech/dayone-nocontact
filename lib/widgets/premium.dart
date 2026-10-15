/// Premium micro-animations for Day One: No Contact.
///
/// - [TickingCounter]: live days/hrs/min/sec streak counter, ticking each
///   second with smooth digit transitions.
/// - [BreathCircle]: SOS breathing exercise — slow scale loop with
///   In/Hold/Out phase text.
/// - [MilestoneCelebration]: full-screen unlock celebration overlay with
///   confetti burst.
/// - [FadeSlidePageRoute]: consistent premium screen transition.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/streak.dart';
import '../theme/app_theme.dart';

/// Live streak counter. Rebuilds once per second; only the seconds text
/// animates to keep the frame budget tiny (60fps-friendly).
class TickingCounter extends StatefulWidget {
  const TickingCounter({super.key, required this.startMs});

  final int startMs;

  @override
  State<TickingCounter> createState() => _TickingCounterState();
}

class _TickingCounterState extends State<TickingCounter> {
  late Timer _timer;
  late ({int days, int hours, int minutes, int seconds}) _parts;

  @override
  void initState() {
    super.initState();
    _parts =
        elapsedParts(widget.startMs, DateTime.now().millisecondsSinceEpoch);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _parts =
            elapsedParts(widget.startMs, DateTime.now().millisecondsSinceEpoch);
      });
    });
  }

  @override
  void didUpdateWidget(TickingCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startMs != widget.startMs) {
      _parts =
          elapsedParts(widget.startMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gentle count-up when the screen first loads — the number
        // climbing feels like progress, not just a label.
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: _parts.days),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            dayLabel(value),
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
        const SizedBox(height: 6),
        // The pill never wraps or overflows: on very long streaks with
        // large system fonts the whole pill scales *down* slightly
        // instead of breaking the layout. Invisible in normal cases.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: DayOneColors.terracottaSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _unit(displayDay(_parts.days), 'd'),
                _sep(),
                _unit(_parts.hours, 'h'),
                _sep(),
                _unit(_parts.minutes, 'm'),
                _sep(),
                // Seconds get the animated treatment.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.6), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOut)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child:
                      _unit(_parts.seconds, 's', key: ValueKey(_parts.seconds)),
                ),
                const SizedBox(width: 4),
                const Text('strong',
                    style: TextStyle(
                        color: DayOneColors.terracottaDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _unit(int v, String suffix, {Key? key}) => Text(
        '$v$suffix',
        key: key,
        style: const TextStyle(
            color: DayOneColors.terracottaDeep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()]),
      );

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Text('·',
            style: TextStyle(color: DayOneColors.terracottaDeep, fontSize: 15)),
      );
}

/// SOS breathing exercise: 4s in, 4s hold, 4s out, looping.
class BreathCircle extends StatefulWidget {
  const BreathCircle({super.key});

  @override
  State<BreathCircle> createState() => _BreathCircleState();
}

class _BreathCircleState extends State<BreathCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _phases = ['Breathe in… 4', 'Hold… 4', 'Breathe out… 4'];

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
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
      builder: (context, _) {
        final t = _ctrl.value; // 0..1 over 12s
        final phase = _phases[(t * 3).floor().clamp(0, 2)];
        // Scale: grow during "in" (0-1/3), hold (1/3-2/3), shrink (2/3-1).
        double scale;
        if (t < 1 / 3) {
          scale = 1.0 + 0.22 * (t * 3);
        } else if (t < 2 / 3) {
          scale = 1.22;
        } else {
          scale = 1.22 - 0.22 * ((t - 2 / 3) * 3);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      DayOneColors.terracottaSoft,
                      DayOneColors.terracotta.withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DayOneColors.terracotta.withValues(alpha: 0.25),
                      blurRadius: 32 * scale,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  phase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DayOneColors.terracottaDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'This urge usually passes in about 20 minutes.\nStay for 60 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DayOneColors.muted, fontSize: 15, height: 1.5),
            ),
          ],
        );
      },
    );
  }
}

/// Full-screen milestone-unlock celebration with confetti.
class MilestoneCelebration extends StatefulWidget {
  const MilestoneCelebration({super.key, required this.day});

  final int day;

  /// Shows the celebration as a dialog. Returns when dismissed.
  static Future<void> show(BuildContext context, int day) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => MilestoneCelebration(day: day),
    );
  }

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) =>
                  CustomPaint(painter: _ConfettiPainter(_ctrl.value)),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
              child: FadeTransition(
                opacity: _ctrl,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 32),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [DayOneColors.gold, Color(0xFFE8C89F)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text('★',
                            style:
                                TextStyle(fontSize: 34, color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      Text('Day ${widget.day} unlocked!',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: DayOneColors.ink)),
                      const SizedBox(height: 8),
                      const Text(
                        'Look how far you\'ve come.\nShare it — someone needs to see this.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: DayOneColors.muted,
                            fontSize: 15.5,
                            height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Keep going'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);
  final double progress;
  final math.Random _rand = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    const count = 70;
    final colors = [
      DayOneColors.terracotta,
      DayOneColors.gold,
      DayOneColors.sage,
      const Color(0xFFE8A07E),
    ];
    for (var i = 0; i < count; i++) {
      final angle = _rand.nextDouble() * math.pi * 2;
      final speed = 0.25 + _rand.nextDouble() * 0.6;
      final dist = progress * speed * size.height * 0.55;
      final x = size.width / 2 + math.cos(angle) * dist;
      final y = size.height * 0.38 +
          math.sin(angle) * dist * 0.8 +
          progress * progress * 140; // gravity
      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + progress * 6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -2.5, 8, 5), const Radius.circular(2)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// Premium page transition: gentle fade + rise.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required Widget child})
      : super(
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, anim, __, child) {
            final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
            final slide = Tween<Offset>(
                    begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}

/// Persistent SOS floating button used on the three main tabs.
class SosFab extends StatelessWidget {
  const SosFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: DayOneColors.sos,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 6,
          shadowColor: DayOneColors.sos.withValues(alpha: 0.4),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        child: const Text('SOS'),
      ),
    );
  }
}

/// A warm little heart that pops after a daily check-in — a tiny hug
/// from the app. Scale-in with elastic ease, gentle fade, auto-dismiss.
class HeartPop {
  HeartPop._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => const _HeartPopBody(),
    );
  }
}

class _HeartPopBody extends StatefulWidget {
  const _HeartPopBody();

  @override
  State<_HeartPopBody> createState() => _HeartPopBodyState();
}

class _HeartPopBodyState extends State<_HeartPopBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward().then((_) {
        if (mounted) Navigator.of(context).pop();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          final scale =
              t < 0.45 ? Curves.elasticOut.transform(t / 0.45) * 1.0 : 1.0;
          final opacity = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: (0.3 + 0.7 * scale).clamp(0.3, 1.2),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DayOneColors.terracotta,
                  boxShadow: [
                    BoxShadow(
                      color: DayOneColors.terracotta.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('♥',
                    style: TextStyle(fontSize: 44, color: Colors.white)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Subtle press feedback for primary CTAs: the button gently shrinks
/// while pressed. Does not steal taps — the child's onPressed still fires.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.96});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
