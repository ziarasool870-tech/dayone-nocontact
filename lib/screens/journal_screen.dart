/// Journal tab: dated entries, newest first, full CRUD. On-device only.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/premium.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, Object?>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries =
        await DayOneDatabase.instance.allJournalEntries();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Map<String, Object?>? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      FadeSlidePageRoute(
          child: JournalEditor(entry: existing)),
    );
    if (changed == true) _reload();
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DayOneColors.card,
        title: const Text('Delete this entry?',
            style: TextStyle(
                color: DayOneColors.ink, fontWeight: FontWeight.w800)),
        content: const Text(
            'This can\'t be undone. Your words matter — are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: DayOneColors.sos)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DayOneDatabase.instance.deleteJournal(id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final created =
                          DateTime.fromMillisecondsSinceEpoch(
                              (e['created_ms'] as num).toInt());
                      final title =
                          (e['title'] as String?) ?? '';
                      final body = (e['body'] as String?) ?? '';
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openEditor(existing: e),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(created),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                            color: DayOneColors
                                                .terracotta),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _delete(
                                          (e['id'] as num).toInt()),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: DayOneColors.muted),
                                      ),
                                    ),
                                  ],
                                ),
                                if (title.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ],
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: DayOneColors.ink),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: DayOneColors.terracotta,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New entry'),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: DayOneColors.terracottaSoft,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.edit_note,
                  size: 32, color: DayOneColors.terracotta),
            ),
            const SizedBox(height: 18),
            const Text('Write it here, not to them.',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'The text you don\'t send is the streak you keep. Start your first entry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: DayOneColors.muted),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _openEditor(),
              child: const Text('Write first entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class JournalEditor extends StatefulWidget {
  const JournalEditor({super.key, this.entry});

  final Map<String, Object?>? entry;

  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
        text: (widget.entry?['title'] as String?) ?? '');
    _body = TextEditingController(
        text: (widget.entry?['body'] as String?) ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final existing = widget.entry;
    if (existing == null) {
      await DayOneDatabase.instance
          .insertJournal(title: title, body: body);
    } else {
      await DayOneDatabase.instance.updateJournal(
        id: (existing['id'] as num).toInt(),
        title: title,
        body: body,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New entry' : 'Edit entry'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: DayOneColors.terracotta)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: 'Title (optional)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const Divider(color: DayOneColors.line, height: 24),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                autofocus: isNew,
                decoration: const InputDecoration(
                  hintText:
                      'What are you feeling right now? Write it all out…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const Text('Private · stored only on your phone',
                style: TextStyle(
                    fontSize: 11.5, color: DayOneColors.muted)),
          ],
        ),
      ),
    );
  }
}
