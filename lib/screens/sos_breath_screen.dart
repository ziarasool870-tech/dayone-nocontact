/// SOS flow: breathing screen → options screen.
///
/// 100% scripted, no AI. This is the moment the app earns its deepest
/// loyalty — being there when the urge hits hardest.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/content.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class SosBreathScreen extends StatelessWidget {
  const SosBreathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS',
            style: TextStyle(color: DayOneColors.sos)),
        backgroundColor: DayOneColors.cream,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Text('Breathe with me',
                  style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: DayOneColors.ink)),
              const SizedBox(height: 8),
              const BreathCircle(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: PressScale(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        FadeSlidePageRoute(
                            child: const SosOptionsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: DayOneColors.sos),
                    child: const Text('I need more help'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text("I'm okay now",
                    style: TextStyle(color: DayOneColors.muted)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class SosOptionsScreen extends StatelessWidget {
  const SosOptionsScreen({super.key});

  void _reasonsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Read this before you text them',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                  'You wrote these on a clear-headed day. Trust that version of you.',
                  style: TextStyle(
                      fontSize: 13, color: DayOneColors.muted)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  itemCount: defaultReasons.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: DayOneColors.terracottaSoft,
                            ),
                            alignment: Alignment.center,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: DayOneColors
                                        .terracottaDeep)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(defaultReasons[i],
                                style: const TextStyle(
                                    fontSize: 14, height: 1.5)),
                          ),
                        ],
                      ),
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

  void _distractSheet(BuildContext context) {
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
            const Text('Move the feeling through you',
                style:
                    TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Pick one. Just one.',
                style:
                    TextStyle(fontSize: 13, color: DayOneColors.muted)),
            const SizedBox(height: 14),
            ...distractionIdeas.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_outlined,
                              size: 20,
                              color: DayOneColors.terracotta),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS',
            style: TextStyle(color: DayOneColors.sos)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text("You're doing great.\nWhat do you need?",
                  style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: DayOneColors.ink)),
              const Spacer(flex: 1),
              _option(
                context,
                icon: Icons.menu_book_outlined,
                title: 'Read my reasons',
                sub: 'Words from your clear-headed self',
                onTap: () => _reasonsSheet(context),
              ),
              _option(
                context,
                icon: Icons.directions_walk_outlined,
                title: 'Distract me',
                sub: 'Small actions that move the urge along',
                onTap: () => _distractSheet(context),
              ),
              _option(
                context,
                icon: Icons.forum_outlined,
                title: 'Text a friend instead',
                sub: 'Tell them one good thing about today',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Good call. Open your messages and tell a friend one good thing about today.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              ),
              const Spacer(flex: 2),
              Card(
                color: const Color(0xFFFFF7EF),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Need to talk to someone right now?',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      _crisisLink(
                          context, 'US: call or text ', '988', '988'),
                      const SizedBox(height: 2),
                      _crisisLink(context, 'UK: Samaritans ', '116 123',
                          '116123'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text("I'm okay now",
                      style: TextStyle(color: DayOneColors.muted)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Tappable crisis-helpline number (opens the phone dialer).
  Widget _crisisLink(
      BuildContext context, String label, String number, String dial) {
    return GestureDetector(
      onTap: () => launchUrl(Uri(scheme: 'tel', path: dial)),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
              fontSize: 13, height: 1.6, color: DayOneColors.muted),
          children: [
            TextSpan(text: label),
            TextSpan(
              text: number,
              style: const TextStyle(
                color: DayOneColors.terracottaDeep,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context,
      {required IconData icon,
      required String title,
      required String sub,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DayOneColors.terracottaSoft,
                  ),
                  child: Icon(icon,
                      color: DayOneColors.terracottaDeep),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: DayOneColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: DayOneColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
