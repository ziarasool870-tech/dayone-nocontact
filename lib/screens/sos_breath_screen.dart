/// SOS flow: breathing screen → options screen.
///
/// 100% scripted, no AI. This is the moment the app earns its deepest
/// loyalty — being there when the urge hits hardest.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/content.dart';
import '../data/prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class SosBreathScreen extends StatelessWidget {
  const SosBreathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS', style: TextStyle(color: DayOneColors.sos)),
        backgroundColor: DayOneColors.cream,
      ),
      body: SafeArea(
        // Scroll-safe on short screens / large fonts: circle stays centered
        // on tall phones, content scrolls instead of overflowing on small ones.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    const Text('Breathe with me',
                        style: TextStyle(
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
          ),
        ),
      ),
    );
  }
}

/// "Read my reasons" bottom sheet: the user's own reasons on top
/// (add / edit / delete), the defaults below with per-item hide,
/// and a restore affordance. Warm, never clinical.
class _ReasonsSheet extends StatefulWidget {
  const _ReasonsSheet();

  @override
  State<_ReasonsSheet> createState() => _ReasonsSheetState();
}

class _ReasonsSheetState extends State<_ReasonsSheet> {
  PrefsService? _prefs;
  List<String> _custom = [];
  Set<int> _hidden = {};
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    PrefsService.instance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _custom = p.customReasons;
        // Clamp to valid indices: a stale/tampered payload must never
        // cause a RangeError when the hidden list is expanded.
        _hidden = p.hiddenDefaultReasons
            .where((i) => i >= 0 && i < defaultReasons.length)
            .toSet();
      });
    });
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setCustomReasons(_custom);
    await p.setHiddenDefaultReasons(_hidden);
  }

  Future<void> _addReason() async {
    final text = await _reasonDialog(title: 'Add your reason');
    if (text == null || text.trim().isEmpty) return;
    setState(() => _custom = [..._custom, text.trim()]);
    await _persist();
  }

  Future<void> _editReason(int index) async {
    final text =
        await _reasonDialog(title: 'Edit your reason', initial: _custom[index]);
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _custom = [..._custom];
      _custom[index] = text.trim();
    });
    await _persist();
  }

  Future<void> _deleteReason(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        title: const Text('Remove this reason?',
            style: TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: const Text('You can always add it back later.',
            style: TextStyle(color: DayOneColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Remove', style: TextStyle(color: DayOneColors.sos)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _custom = [..._custom]..removeAt(index);
    });
    await _persist();
  }

  /// Add / edit dialog with explicit ink-on-card styling —
  /// never white-on-white.
  Future<String?> _reasonDialog({required String title, String? initial}) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        // Scrollable: with the keyboard open on small screens + large
        // fonts, the actions must never clip out of reach.
        scrollable: true,
        title: Text(title,
            style: const TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: DayOneColors.ink),
          decoration: const InputDecoration(
            hintText: 'Words from your clear-headed self…',
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
  }

  @override
  Widget build(BuildContext context) {
    final visibleDefaults = [
      for (var i = 0; i < defaultReasons.length; i++)
        if (!_hidden.contains(i)) i
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Read this before you text them',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'You wrote these on a clear-headed day. Trust that version of you.',
                style: TextStyle(fontSize: 15, color: DayOneColors.muted)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addReason,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add your own reason'),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: ctrl,
                children: [
                  ..._custom
                      .asMap()
                      .entries
                      .map((e) => _customCard(e.key, e.value)),
                  ...visibleDefaults.map(_defaultCard),
                  if (_custom.isEmpty && visibleDefaults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'Add your first reason above —\nyour own words hit hardest.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: DayOneColors.muted),
                      ),
                    ),
                  if (_hidden.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _showHidden = !_showHidden),
                        child: Text(_showHidden
                            ? 'Hide hidden reasons'
                            : 'Show ${_hidden.length} hidden reason${_hidden.length == 1 ? '' : 's'}'),
                      ),
                    ),
                    if (_showHidden) ...[
                      ..._hidden.map(_hiddenCard),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            setState(() {
                              _hidden = {};
                              _showHidden = false;
                            });
                            await _persist();
                          },
                          child: const Text('Restore all defaults'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card for a user-written reason: heart badge + edit/delete.
  Widget _customCard(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DayOneColors.terracottaSoft,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite,
                    size: 15, color: DayOneColors.terracottaDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
              _iconBtn(
                  Icons.edit_outlined, () => _editReason(index), 'Edit reason'),
              _iconBtn(Icons.delete_outline, () => _deleteReason(index),
                  'Delete reason'),
            ],
          ),
        ),
      ),
    );
  }

  /// Card for a default reason: number badge + hide button.
  Widget _defaultCard(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 15,
                        color: DayOneColors.terracottaDeep)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(defaultReasons[i],
                    style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
              _iconBtn(Icons.visibility_off_outlined, () async {
                setState(() => _hidden = {..._hidden, i});
                await _persist();
              }, 'Hide this reason'),
            ],
          ),
        ),
      ),
    );
  }

  /// Dimmed card for a hidden default, with an unhide button.
  Widget _hiddenCard(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: 0.55,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(defaultReasons[i],
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: DayOneColors.muted)),
                ),
                _iconBtn(Icons.visibility_outlined, () async {
                  final next = {..._hidden}..remove(i);
                  setState(() => _hidden = next);
                  await _persist();
                }, 'Show this reason'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, String tooltip) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(icon, size: 19, color: DayOneColors.muted),
        onPressed: onTap,
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
      builder: (_) => const _ReasonsSheet(),
    );
  }

  void _distractSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Scroll-controlled + draggable: every card stays reachable on
      // small screens and large system fonts (was overflowing 300px+).
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Move the feeling through you',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Pick one. Just one.',
                  style: TextStyle(fontSize: 15, color: DayOneColors.muted)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  children: [
                    ...distractionIdeas.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt_outlined,
                                      size: 20, color: DayOneColors.terracotta),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(d,
                                        style: const TextStyle(
                                            fontSize: 15.5, height: 1.45)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS', style: TextStyle(color: DayOneColors.sos)),
      ),
      body: SafeArea(
        // Scroll-safe on short screens: the spacers distribute extra
        // room on tall phones, and the content scrolls on small ones
        // instead of overflowing.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text("You're doing great.\nWhat do you need?",
                        style: TextStyle(
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
                      onTap: () => launchUrl(Uri(scheme: 'sms')),
                    ),
                    const Spacer(flex: 2),
                    _crisisCard(context),
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
          ),
        ),
      ),
    );
  }

  /// Locale-aware crisis card: the helpline for the user's country,
  /// tappable to dial, plus a "more countries" fallback link.
  Widget _crisisCard(BuildContext context) {
    final entry = resolveCrisisHelpline(
      WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
    return Card(
      color: const Color(0xFFFFF7EF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need to talk to someone right now?',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => launchUrl(Uri(scheme: 'tel', path: entry['dial'])),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: DayOneColors.muted),
                  children: [
                    TextSpan(text: entry['prefix']),
                    TextSpan(
                      text: entry['number'],
                      style: const TextStyle(
                        color: DayOneColors.terracottaDeep,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(crisisFallbackUrl),
                  mode: LaunchMode.externalApplication),
              child: const Text(
                'More countries →',
                style: TextStyle(
                  fontSize: 13.5,
                  color: DayOneColors.muted,
                  decoration: TextDecoration.underline,
                ),
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
                  child: Icon(icon, color: DayOneColors.terracottaDeep),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 14.5, color: DayOneColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: DayOneColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
