import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/filter.dart';
import '../core/library_controller.dart';
import '../core/model.dart';
import '../core/tags.dart';
import 'add_book_screen.dart';
import 'book_screen.dart';
import 'cover.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'tag_picker.dart';
import 'theme.dart';

const visibleChips = 12;

String stars(int rating) => '★' * rating + '☆' * (5 - rating);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FilterState _filter = FilterState();

  String get _title => switch (_filter.status) {
        StatusFilter.toRead => 'Ma pile à lire',
        StatusFilter.reading => 'En cours',
        StatusFilter.read => 'Mes lectures',
        StatusFilter.all => 'Tous mes livres',
      };

  Future<void> _openPicker(List<MapEntry<String, int>> counts) async {
    final result = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(builder: (_) => TagPicker(counts: counts, selected: _filter.tags)),
    );
    if (result != null) setState(() => _filter.tags = result);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>().library;
    final books = filterBooks(lib.books.values, _filter);
    final counts = chipCounts(lib.books.values, _filter.status);
    final chipNames = <String>[
      ..._filter.tags,
      ...counts.map((e) => e.key).where((n) => !_filter.tags.contains(n)).take(visibleChips),
    ];
    final gc = context.gc;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Synchroniser',
            icon: const Icon(Icons.sync),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen())),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un livre',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBookScreen())),
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Rechercher un titre, un auteur…', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _filter.query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in chipNames)
                      FilterChip(
                        label: Text(name),
                        selected: _filter.tags.contains(name),
                        onSelected: (on) => setState(() => on ? _filter.tags.add(name) : _filter.tags.remove(name)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Plus'),
                      tooltip: 'Tous les thèmes et tropes',
                      onPressed: () => _openPicker(counts),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SegmentedButton<StatusFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: StatusFilter.toRead, label: Text('À lire')),
                    ButtonSegment(value: StatusFilter.reading, label: Text('En cours')),
                    ButtonSegment(value: StatusFilter.read, label: Text('Lus')),
                    ButtonSegment(value: StatusFilter.all, label: Text('Tout')),
                  ],
                  selected: {_filter.status},
                  onSelectionChanged: (s) => setState(() => _filter.status = s.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  books.length <= 1 ? '${books.length} livre correspond' : '${books.length} livres correspondent',
                  style: TextStyle(color: gc.muted, fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 16, endIndent: 16, color: gc.surface),
                  itemBuilder: (context, i) => _BookRow(books[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final Book book;
  const _BookRow(this.book);

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final tags = displayTags(book).take(3).map((t) => t.name).join(' · ');
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookScreen(bookId: book.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Cover(book),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(book.authors.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: gc.muted, fontSize: 13)),
                  if (tags.isNotEmpty)
                    Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: gc.muted, fontSize: 12)),
                  Row(
                    children: [
                      if (book.rating > 0) Text(stars(book.rating), style: TextStyle(color: gc.title, fontSize: 13)),
                      if (book.rating > 0 && needsCompletion(book)) const SizedBox(width: 8),
                      if (needsCompletion(book))
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: gc.surface, borderRadius: BorderRadius.circular(8)),
                          child: Text('à compléter', style: TextStyle(color: gc.muted, fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
