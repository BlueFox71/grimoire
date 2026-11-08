import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/filter.dart';
import '../core/library_controller.dart';
import '../core/model.dart';
import '../core/tags.dart';
import 'add_book_screen.dart';
import 'book_screen.dart';
import 'cover.dart';
import 'pinned_tags.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'tag_picker.dart';
import 'theme.dart';

/// Nombre maximal de pastilles de thème avant « Plus » (les épinglés, ou à défaut les plus fréquents).
const visibleChips = 5;

String stars(int rating) => '★' * rating;

/// Accueil « mur de couvertures » : recherche, pastilles de filtre qui défilent,
/// grille de couvertures et barre de navigation flottante.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FilterState _filter = FilterState();

  String get _title => switch (_filter.status) {
    StatusFilter.toRead => 'Ma pile',
    StatusFilter.reading => 'En cours',
    StatusFilter.read => 'Mes lectures',
    StatusFilter.all => 'Tous mes livres',
  };

  Future<void> _openPicker(List<MapEntry<String, int>> counts) async {
    final result = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => TagPicker(counts: counts, selected: _filter.tags),
      ),
    );
    if (result != null) setState(() => _filter.tags = result);
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>().library;
    final books = filterBooks(lib.books.values, _filter);
    final counts = chipCounts(lib.books.values, _filter.status);
    final pinned = context.watch<PinnedTags>().pinned;
    // Thèmes épinglés seulement (5 au plus) ; sans épingle, les 5 plus fréquents.
    final base = pinned.isNotEmpty
        ? pinned.take(visibleChips).toList()
        : counts.map((e) => e.key).take(visibleChips).toList();
    // Un filtre coché hors des 5 reste visible (en tête), pour pouvoir le décocher.
    final chipNames = <String>[
      ..._filter.tags.where((t) => !base.contains(t)),
      ...base,
    ];
    final gc = context.gc;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(child: Text(_title, style: displayStyle(34, gc.title))),
                        IconButton(
                          tooltip: 'Ajouter un livre',
                          icon: const Icon(Icons.add),
                          onPressed: () => _open(const AddBookScreen()),
                        ),
                        IconButton(
                          tooltip: 'Réglages',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => _open(const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un titre, un auteur…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (v) => setState(() => _filter.query = v),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      children: [
                        for (final name in chipNames)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(name),
                              showCheckmark: false,
                              selected: _filter.tags.contains(name),
                              onSelected: (on) =>
                                  setState(() => on ? _filter.tags.add(name) : _filter.tags.remove(name)),
                            ),
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
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      books.length <= 1 ? '${books.length} livre' : '${books.length} livres',
                      style: TextStyle(color: gc.muted, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        lib.visible.isEmpty
                            ? 'Ta bibliothèque est vide. Sur le PC, importe ton export Booknode depuis les réglages ; sur le téléphone, lance une synchro.'
                            : 'Aucun livre ne correspond à ces filtres.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: gc.muted),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 110 + bottomInset),
                    sliver: SliverGrid(
                      key: const Key('cover-grid'),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.52,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _CoverTile(books[i], onTap: () => _open(BookScreen(bookId: books[i].id))),
                        childCount: books.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        status: _filter.status,
        onStatus: (s) => setState(() => _filter.status = s),
        onSync: () => _open(const SyncScreen()),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _CoverTile(this.book, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final incomplete = needsCompletion(book);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(builder: (context, c) => Cover(book, width: c.maxWidth, radius: 12)),
                ),
                if (book.rating > 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _Badge(
                      child: Text(
                        stars(book.rating),
                        style: TextStyle(color: gc.title, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                if (incomplete)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Semantics(
                      label: 'à compléter',
                      child: Tooltip(
                        message: 'À compléter : peu de thèmes',
                        child: _Badge(child: Icon(Icons.auto_awesome, size: 13, color: gc.title)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25),
          ),
          const SizedBox(height: 2),
          Text(
            book.authors.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: gc.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
    child: child,
  );
}

/// Barre de navigation flottante en bas de l'écran.
class _FloatingNav extends StatelessWidget {
  final StatusFilter status;
  final ValueChanged<StatusFilter> onStatus;
  final VoidCallback onSync;
  const _FloatingNav({required this.status, required this.onStatus, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    Widget item(IconData icon, String label, bool selected, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? gc.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? gc.onAccent : gc.muted),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? gc.onAccent : gc.muted),
              ),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Material(
              color: Colors.transparent,
              elevation: 10,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                key: const Key('nav'),
                height: 64,
                decoration: BoxDecoration(
                  color: gc.surface.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gc.muted.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    item(Icons.menu_book, 'Pile', status == StatusFilter.toRead, () => onStatus(StatusFilter.toRead)),
                    item(
                      Icons.bookmark,
                      'En cours',
                      status == StatusFilter.reading,
                      () => onStatus(StatusFilter.reading),
                    ),
                    item(Icons.star, 'Lus', status == StatusFilter.read, () => onStatus(StatusFilter.read)),
                    item(Icons.sync, 'Synchro', false, onSync),
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
