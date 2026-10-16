/// Unsent-letter vault: write what you'll never send, seal it, keep it.
/// Pro-gated. Letters live only on this device.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<Map<String, Object?>> _letters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final letters = await DayOneDatabase.instance.allLetters();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Letter vault')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _letters.isEmpty
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty
                                          ? 'Untitled letter'
                                          : title,
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
      floatingActionButton: FloatingActionButton.extended(
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
