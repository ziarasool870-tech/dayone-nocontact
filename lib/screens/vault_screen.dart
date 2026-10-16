/// Unsent-letter vault: write what you'll never send, seal it, keep it.
/// Two tabs: "Letters" (tender, unsent) and "Let it out" (raw vents you burn).
/// Pro-gated at the entry points. Letters and vents live only on this device.
///
/// Mission guardrail: this feature moves the user ON, never back to the ex.
/// Burn is always the hero action; there is no "send" anywhere — ever.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';
import '../services/notification_service.dart';

/// Seven days in milliseconds — vents older than this get a gentle nudge.
const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

/// First non-empty line of a vent, for list previews.
@visibleForTesting
String ventPreview(String body) {
  for (final line in body.split('\n')) {
    final t = line.trim();
    if (t.isNotEmpty) return t;
  }
  return 'Untitled vent';
}

/// True when a vent was created more than seven days ago (and is unburned).
@visibleForTesting
bool needsWeekNudge(int createdMs, int nowMs) =>
    nowMs - createdMs > sevenDaysMs;

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Letter vault'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Letters'),
              Tab(text: 'Let it out'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LettersTab(),
            _VentsTab(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ letters

class _LettersTab extends StatefulWidget {
  const _LettersTab();

  @override
  State<_LettersTab> createState() => _LettersTabState();
}

class _LettersTabState extends State<_LettersTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, Object?>> _letters = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final letters = await DayOneDatabase.instance.allLetters(kind: 'letter');
    if (mounted) {
      setState(() {
        _letters = letters;
        _loading = false;
      });
    }
  }

  Future<void> _compose() async {
    final sealed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: const LetterComposer()),
    );
    if (sealed == true) _reload();
  }

  Future<void> _open(Map<String, Object?> letter) async {
    final changed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: LetterReader(letter: letter)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _letters.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: _letters.length,
              itemBuilder: (ctx, i) {
                final l = _letters[i];
                final title = ((l['title'] as String?) ?? '').trim();
                final body = ((l['body'] as String?) ?? '').trim();
                final when = DateTime.fromMillisecondsSinceEpoch(
                    (l['created_ms'] as num).toInt());
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _open(l),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: DayOneColors.terracottaSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.mail_outline,
                                color: DayOneColors.terracottaDeep),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.isEmpty ? 'Untitled letter' : title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('d MMMM yyyy').format(when),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: DayOneColors.muted),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: DayOneColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _letters.isEmpty
          ? null // Empty state already has its own CTA — no duplicate button.
          : FloatingActionButton.extended(
              onPressed: _compose,
              backgroundColor: DayOneColors.terracotta,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: const Text('Write a letter',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      children: [
        const Center(
          child: Text('✉️', style: TextStyle(fontSize: 56)),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('The unsent-letter vault',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Some things need to be said — just not sent.\n'
            'Write it here, seal it, and let it rest.\n'
            'It stays on this phone, only for you.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.6, color: DayOneColors.muted),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: _compose,
            style: ElevatedButton.styleFrom(
              backgroundColor: DayOneColors.terracotta,
              minimumSize: const Size(200, 52),
            ),
            child: const Text('Write your first letter'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- vents

class _VentsTab extends StatefulWidget {
  const _VentsTab();

  @override
  State<_VentsTab> createState() => _VentsTabState();
}

class _VentsTabState extends State<_VentsTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, Object?>> _vents = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final vents = await DayOneDatabase.instance.allLetters(kind: 'vent');
    if (mounted) {
      setState(() {
        _vents = vents;
        _loading = false;
      });
    }
  }

  Future<void> _compose() async {
    final sealed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: const VentComposer()),
    );
    if (sealed == true) _reload();
  }

  Future<void> _open(Map<String, Object?> vent) async {
    final changed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: VentReader(vent: vent)),
    );
    if (changed == true) _reload();
  }

  Future<void> _burnFromList(Map<String, Object?> vent) async {
    final id = (vent['id'] as num).toInt();
    final burned = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: VentBurnRitual(ventId: id)),
    );
    if (burned == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final hasOld = _vents.any((v) =>
        needsWeekNudge((v['created_ms'] as num).toInt(), now));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _vents.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: _vents.length + (hasOld ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (hasOld && i == 0) return _weekNudge();
                final v = _vents[hasOld ? i - 1 : i];
                final body = ((v['body'] as String?) ?? '').trim();
                final when = DateTime.fromMillisecondsSinceEpoch(
                    (v['created_ms'] as num).toInt());
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _open(v),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: DayOneColors.terracottaSoft,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Center(
                              child: Text('🔥',
                                  style: TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ventPreview(body),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('d MMMM yyyy').format(when)} · tap to re-read',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: DayOneColors.muted),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _burnFromList(v),
                            child: const Text('Burn',
                                style: TextStyle(
                                    color: DayOneColors.terracottaDeep,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _vents.isEmpty
          ? null // Empty state already has its own CTA — no duplicate button.
          : FloatingActionButton.extended(
              onPressed: _compose,
              backgroundColor: DayOneColors.terracotta,
              icon: const Text('🔥', style: TextStyle(fontSize: 20)),
              label: const Text('Let it out',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  Widget _weekNudge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DayOneColors.goldSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DayOneColors.goldBorder),
      ),
      child: const Text(
        "This one's been sitting for a week — ready to let it go?",
        style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: DayOneColors.muted),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      children: [
        const Center(
          child: Text('🔥', style: TextStyle(fontSize: 56)),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('Let it out',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Get the anger out here.\n'
            'No one will read it. No one will judge.\n'
            'Write it raw, sleep on it, then burn it\n'
            'and travel lighter.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.6, color: DayOneColors.muted),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: _compose,
            style: ElevatedButton.styleFrom(
              backgroundColor: DayOneColors.terracotta,
              minimumSize: const Size(200, 52),
            ),
            child: const Text('Let it out'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ vent compose

/// Compose + seal a raw vent. No title — vents are unfiltered by design.
class VentComposer extends StatefulWidget {
  const VentComposer({super.key});

  @override
  State<VentComposer> createState() => _VentComposerState();
}

class _VentComposerState extends State<VentComposer> {
  final _bodyCtrl = TextEditingController();
  bool _sealing = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _seal() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Let it out — even one line counts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _sealing = true);
    final ventId = await DayOneDatabase.instance.insertLetter(
      title: '',
      body: body,
      kind: 'vent',
    );
    // 24h discreet re-read nudge. Skips silently if blocked — never nags.
    await NotificationService.instance.scheduleVentReminder(ventId: ventId);
    if (!mounted) return;
    // Encouragement + shame antidote. A button is mandatory — a dialog
    // with no way out is a trap (v9 lesson).
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text("It's out.",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                "That took courage.\n"
                "Anger is grief with nowhere to go —\n"
                "you're allowed to feel it.\n"
                "I'll see you here tomorrow.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.5, height: 1.5, color: DayOneColors.muted)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DayOneColors.terracotta,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Okay'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    // Forward: land on the Let-it-out tab list with the new vent on top.
    await returnToVentList(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Let it out')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _bodyCtrl,
            maxLines: null,
            minLines: 12,
            autofocus: true,
            style: const TextStyle(
                fontSize: 16, height: 1.6, color: DayOneColors.ink),
            decoration: const InputDecoration(
              hintText: 'Say everything. The anger, the hurt, all of it — '
                  'no one will ever read this…',
              hintStyle: TextStyle(color: DayOneColors.faint, height: 1.6),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sealing ? null : _seal,
              style: ElevatedButton.styleFrom(
                backgroundColor: DayOneColors.terracotta,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _sealing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Seal it 🔥'),
            ),
          ),
        ],
      ),
    );
  }
}

/// After the vent sealing dialog closes, land on the Let-it-out tab list.
/// Mirrors [returnToVaultList]: normally a plain pop returns to the vault
/// (tab state is preserved); defensively swaps to the vent tab if the
/// composer was somehow opened standalone.
@visibleForTesting
Future<void> returnToVentList(BuildContext context) async {
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop(true);
  } else {
    nav.pushReplacement(
      FadeSlidePageRoute(child: const VaultScreen(initialTab: 1)),
    );
  }
}

// -------------------------------------------------------------- vent read

/// Re-read a vent after the 24h nudge (or from the list).
/// Mission line is explicit: this was never meant to be sent.
/// Burn is the hero; Keep is secondary. There is no send — ever.
class VentReader extends StatelessWidget {
  const VentReader({super.key, required this.vent});

  final Map<String, Object?> vent;

  Future<void> _burn(BuildContext context) async {
    final id = (vent['id'] as num).toInt();
    final burned = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(child: VentBurnRitual(ventId: id)),
    );
    if (burned == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ((vent['body'] as String?) ?? '').trim();
    final when = DateTime.fromMillisecondsSinceEpoch(
        (vent['created_ms'] as num).toInt());
    return Scaffold(
      appBar: AppBar(title: const Text("Yesterday's vent")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            DateFormat('d MMMM yyyy').format(when),
            style:
                const TextStyle(fontSize: 13.5, color: DayOneColors.muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: DayOneColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DayOneColors.cardBorder),
            ),
            child: Text(body,
                style: const TextStyle(
                    fontSize: 16, height: 1.65, color: DayOneColors.ink)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DayOneColors.terracottaSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '"This was never meant to be sent — and that\'s its power."',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: DayOneColors.muted),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Do you still feel this way?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _burn(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: DayOneColors.terracotta,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('🔥 Burn it'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: DayOneColors.line),
              ),
              child: const Text('Keep it',
                  style: TextStyle(color: DayOneColors.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ burn ritual

/// The payoff moment: the vent is deleted (and its 24h nudge cancelled),
/// then a quiet full-screen beat — flame, "Burned.", and a small gift.
/// Forward-facing copy only: freedom, lightness, dignity.
class VentBurnRitual extends StatefulWidget {
  const VentBurnRitual({super.key, required this.ventId});

  final int ventId;

  @override
  State<VentBurnRitual> createState() => _VentBurnRitualState();
}

class _VentBurnRitualState extends State<VentBurnRitual> {
  @override
  void initState() {
    super.initState();
    _burn();
  }

  Future<void> _burn() async {
    await DayOneDatabase.instance.deleteLetter(widget.ventId);
    await NotificationService.instance.cancelVentReminder(widget.ventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Let it out')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(
          children: [
            const Spacer(),
            const Text('🔥', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text('Burned.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'You burned the anger and kept your dignity.\nLighter now?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  height: 1.65,
                  fontStyle: FontStyle.italic,
                  color: DayOneColors.muted),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DayOneColors.terracotta,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- letter (existing)

/// Compose + seal a new letter.
class LetterComposer extends StatefulWidget {
  const LetterComposer({super.key});

  @override
  State<LetterComposer> createState() => _LetterComposerState();
}

class _LetterComposerState extends State<LetterComposer> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sealing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _seal() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a little first — even one line counts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _sealing = true);
    await DayOneDatabase.instance.insertLetter(
      title: _titleCtrl.text.trim(),
      body: body,
    );
    if (!mounted) return;
    // The sealing ritual: a quiet moment before returning.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✉️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text('Sealed.',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text("It's yours now. You never have to send it.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.5, height: 1.5, color: DayOneColors.muted)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DayOneColors.terracotta,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('See your letters'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    // Forward: land on the vault list with the new letter on top.
    await returnToVaultList(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a letter')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DayOneColors.ink),
            decoration: const InputDecoration(
              hintText: 'Title (optional)',
              hintStyle: TextStyle(color: DayOneColors.faint),
              border: InputBorder.none,
            ),
          ),
          const Divider(color: DayOneColors.line),
          TextField(
            controller: _bodyCtrl,
            maxLines: null,
            minLines: 12,
            autofocus: true,
            style: const TextStyle(
                fontSize: 16, height: 1.6, color: DayOneColors.ink),
            decoration: const InputDecoration(
              hintText: 'Dear…\n\nSay everything. Send nothing.',
              hintStyle: TextStyle(color: DayOneColors.faint, height: 1.6),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sealing ? null : _seal,
              style: ElevatedButton.styleFrom(
                backgroundColor: DayOneColors.terracotta,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _sealing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Seal it ✉️'),
            ),
          ),
        ],
      ),
    );
  }
}

/// After the sealing dialog closes, land on the vault list.
/// Normally the composer was pushed above [VaultScreen], so a plain pop
/// returns there (and triggers its reload). Defensively, if the composer
/// was somehow opened standalone, swap to the vault list instead of
/// popping into void.
@visibleForTesting
Future<void> returnToVaultList(BuildContext context) async {
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop(true);
  } else {
    nav.pushReplacement(
      FadeSlidePageRoute(child: const VaultScreen()),
    );
  }
}

/// Read a sealed letter; delete with confirmation.
class LetterReader extends StatelessWidget {
  const LetterReader({super.key, required this.letter});

  final Map<String, Object?> letter;

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        title: const Text('Burn this letter?',
            style:
                TextStyle(color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: const Text(
            'Once it\'s gone, it\'s gone. Sometimes that\'s the point — are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Burn it',
                style: TextStyle(color: DayOneColors.terracottaDeep)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DayOneDatabase.instance
          .deleteLetter((letter['id'] as num).toInt());
      if (context.mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = ((letter['title'] as String?) ?? '').trim();
    final body = ((letter['body'] as String?) ?? '').trim();
    final when = DateTime.fromMillisecondsSinceEpoch(
        (letter['created_ms'] as num).toInt());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sealed letter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            DateFormat('d MMMM yyyy').format(when),
            style:
                const TextStyle(fontSize: 13.5, color: DayOneColors.muted),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 12),
          Text(body,
              style: const TextStyle(
                  fontSize: 16, height: 1.65, color: DayOneColors.ink)),
        ],
      ),
    );
  }
}
