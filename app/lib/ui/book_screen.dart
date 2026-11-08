import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library_controller.dart';
import '../core/model.dart';
import '../core/tags.dart';
import 'cover.dart';
import 'theme.dart';

class BookScreen extends StatefulWidget {
  final String bookId;
  const BookScreen({super.key, required this.bookId});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late final TextEditingController _comment;
  late final LibraryController _library;
  final FocusNode _commentFocus = FocusNode();
  bool _summaryOpen = false;

  @override
  void initState() {
    super.initState();
    _library = context.read<LibraryController>();
    final b = _library.book(widget.bookId);
    _comment = TextEditingController(text: b?.comment ?? '');
    _commentFocus.addListener(() {
      if (!_commentFocus.hasFocus) _saveComment();
    });
  }

  @override
  void dispose() {
    _saveComment();
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _saveComment() {
    final b = _library.book(widget.bookId);
    if (b != null && b.comment != _comment.text) {
      _library.edit(widget.bookId, 'comment', (b) => b.comment = _comment.text);
    }
  }

  void _setStatus(ReadStatus s) {
    context.read<LibraryController>().edit(widget.bookId, 'status', (b) {
      b.status = s;
      b.readAt = s == ReadStatus.read ? DateTime.now().toUtc() : null;
    });
  }

  void _setRating(int r) {
    context.read<LibraryController>().edit(widget.bookId, 'rating', (b) => b.rating = b.rating == r ? 0 : r);
  }

  void _removeTag(Tag t) {
    context.read<LibraryController>().edit(widget.bookId, 'tags', (b) {
      b.manualAdded.remove('${t.kind.name}:${t.name}');
      if (b.tags.any((x) => x.name == t.name)) b.manualRemoved.add(t.name);
    });
  }

  Future<void> _addTag() async {
    final lib = context.read<LibraryController>().library;
    final known = <String>{for (final b in lib.visible) ...displayTags(b).map((t) => t.name)}.toList()..sort();
    final result = await showModalBottomSheet<(TagKind, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTagSheet(known: known),
    );
    if (result == null || !mounted) return;
    final (kind, name) = result;
    context.read<LibraryController>().edit(widget.bookId, 'tags', (b) {
      b.manualRemoved.remove(name);
      if (!b.tags.any((x) => x.name == name && isKept(x))) b.manualAdded.add('${kind.name}:$name');
    });
  }

  Future<void> _confirmRemove(Book b) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Retirer « ${b.title} » ?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Il ne reviendra pas au prochain import.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    context.read<LibraryController>().edit(widget.bookId, 'deleted', (b) => b.deleted = true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<LibraryController>().book(widget.bookId);
    if (b == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Livre introuvable')));
    final gc = context.gc;
    final tags = displayTags(b);
    final themes = tags.where((t) => t.kind == TagKind.theme).toList();
    final tropes = tags.where((t) => t.kind == TagKind.trope).toList();
    final vol = b.volume == null ? '' : ', tome ${b.volume is double && b.volume! % 1 != 0 ? b.volume : b.volume!.toInt()}';

    Widget tagWrap(List<Tag> list) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in list)
              GestureDetector(
                onLongPress: () => _removeTag(t),
                child: Chip(label: Text(t.name)),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(b, width: 110),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(b.authors.join(', '), style: TextStyle(color: gc.muted)),
                        if (b.series != null) ...[
                          const SizedBox(height: 4),
                          Text('${b.series}$vol', style: TextStyle(color: gc.muted, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              InkResponse(
                                key: Key('star-$i'),
                                radius: 20,
                                onTap: () => _setRating(i),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(i <= b.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: gc.title, size: 28),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusButton(label: 'À lire', selected: b.status == ReadStatus.toRead, onTap: () => _setStatus(ReadStatus.toRead)),
                  _StatusButton(label: 'Je le lis', selected: b.status == ReadStatus.reading, onTap: () => _setStatus(ReadStatus.reading)),
                  _StatusButton(label: 'Lu', selected: b.status == ReadStatus.read, onTap: () => _setStatus(ReadStatus.read)),
                ],
              ),
              if (b.summary != null && b.summary!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Résumé', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _summaryOpen = !_summaryOpen),
                  child: Text(b.summary!, maxLines: _summaryOpen ? null : 6, overflow: _summaryOpen ? null : TextOverflow.fade, style: const TextStyle(height: 1.45)),
                ),
              ],
              const SizedBox(height: 20),
              Text('Thèmes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              themes.isEmpty ? Text('Aucun thème', style: TextStyle(color: gc.muted)) : tagWrap(themes),
              const SizedBox(height: 14),
              Text('Tropes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              tropes.isEmpty ? Text('Aucun trope', style: TextStyle(color: gc.muted)) : tagWrap(tropes),
              const SizedBox(height: 6),
              Text('Appui long sur une étiquette pour la retirer.', style: TextStyle(color: gc.muted, fontSize: 12)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: _addTag, icon: const Icon(Icons.add), label: const Text('Ajouter une étiquette')),
              ),
              const SizedBox(height: 14),
              Text('Mon avis', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              TextField(
                key: const Key('comment'),
                controller: _comment,
                focusNode: _commentFocus,
                minLines: 2,
                maxLines: 6,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Ce que tu en as pensé…'),
                onChanged: (_) => _saveComment(),
                onSubmitted: (_) => _saveComment(),
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _confirmRemove(b),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Retirer de Grimoire'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      selected ? FilledButton(onPressed: onTap, child: Text(label)) : OutlinedButton(onPressed: onTap, child: Text(label));
}

class _AddTagSheet extends StatefulWidget {
  final List<String> known;
  const _AddTagSheet({required this.known});

  @override
  State<_AddTagSheet> createState() => _AddTagSheetState();
}

class _AddTagSheetState extends State<_AddTagSheet> {
  TagKind _kind = TagKind.theme;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isNotEmpty) Navigator.pop(context, (_kind, n));
  }

  @override
  Widget build(BuildContext context) {
    final q = normalize(_name.text);
    final suggestions = q.isEmpty ? <String>[] : widget.known.where((k) => normalize(k).contains(q)).take(8).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ajouter une étiquette', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<TagKind>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TagKind.theme, label: Text('Thème')),
              ButtonSegment(value: TagKind.trope, label: Text('Trope')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('new-tag'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nom (ex. Fae, Slow burn…)'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => setState(() => _name.text = s)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _submit, child: const Text('Ajouter'))),
        ],
      ),
    );
  }
}
