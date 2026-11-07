import 'dart:async';

import 'package:flutter/foundation.dart';

import 'library_store.dart';
import 'model.dart';

/// Bibliothèque en mémoire + sauvegarde. Toute modification faite par Jules
/// passe par [edit], qui horodate le groupe de champs concerné.
class LibraryController extends ChangeNotifier {
  final LibraryStore store;
  Library _library;
  Timer? _saveTimer;
  bool loaded;

  LibraryController(this.store, {Library? initial})
      : _library = initial ?? Library(),
        loaded = initial != null;

  Library get library => _library;

  Book? book(String id) => _library.books[id];

  Future<void> load() async {
    _library = await store.load();
    loaded = true;
    notifyListeners();
  }

  /// Modifie un livre au nom de Jules : `updatedAt` et `userEditedAt` du groupe passent à maintenant.
  void edit(String bookId, String group, void Function(Book) change) {
    final b = _library.books[bookId];
    if (b == null) return;
    change(b);
    final now = DateTime.now().toUtc();
    b.updatedAt[group] = now;
    b.userEditedAt[group] = now;
    notifyListeners();
    _scheduleSave();
  }

  void addBook(Book b) {
    _library.books[b.id] = b;
    notifyListeners();
    _scheduleSave();
  }

  /// Remplace toute la bibliothèque (après import ou synchro) et l'enregistre aussitôt.
  Future<void> replace(Library lib) async {
    _library = lib;
    notifyListeners();
    _saveTimer?.cancel();
    await store.save(_library);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await store.save(_library);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
