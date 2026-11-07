import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/google_books.dart';
import '../core/library_controller.dart';
import '../core/model.dart';
import 'book_screen.dart';
import 'cover.dart';
import 'theme.dart';

typedef BookSearch = Future<List<BookCandidate>> Function(String query);

class AddBookScreen extends StatefulWidget {
  final BookSearch? search;
  const AddBookScreen({super.key, this.search});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _query = TextEditingController();
  List<BookCandidate>? _results;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await (widget.search ?? searchBooks)(q);
      if (mounted) setState(() => _results = r);
    } on BookSearchException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(Book b) {
    context.read<LibraryController>().addBook(b);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BookScreen(bookId: b.id)));
  }

  Future<void> _manual() async {
    final c = await showModalBottomSheet<BookCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualSheet(),
    );
    if (c != null && mounted) _add(candidateToBook(c, DateTime.now().toUtc()));
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un livre')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  key: const Key('search'),
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Titre ou auteur',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton.icon(onPressed: _manual, icon: const Icon(Icons.edit_outlined), label: const Text('Ajouter à la main')),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: gc.muted))),
              if (results != null && results.isEmpty && _error == null)
                Padding(padding: const EdgeInsets.all(16), child: Text('Aucun résultat. Tu peux l\'ajouter à la main.', style: TextStyle(color: gc.muted))),
              if (results != null)
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final c = results[i];
                      final preview = Book(id: 'preview', title: c.title, authors: c.authors, type: 'livre', addedAt: DateTime.now())
                        ..coverUrl = c.coverUrl;
                      return ListTile(
                        leading: Cover(preview, width: 36),
                        title: Text(c.title),
                        subtitle: Text(c.authors.join(', ')),
                        onTap: () => _add(candidateToBook(c, DateTime.now().toUtc())),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualSheet extends StatefulWidget {
  const _ManualSheet();

  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  final _title = TextEditingController();
  final _author = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    final a = _author.text.trim();
    Navigator.pop(context, BookCandidate(title: t, authors: a.isEmpty ? [] : [a]));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouveau livre', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(key: const Key('manual-title'), controller: _title, autofocus: true, decoration: const InputDecoration(hintText: 'Titre')),
            const SizedBox(height: 8),
            TextField(key: const Key('manual-author'), controller: _author, decoration: const InputDecoration(hintText: 'Auteur ou autrice')),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _submit, child: const Text('Créer la fiche'))),
          ],
        ),
      );
}
