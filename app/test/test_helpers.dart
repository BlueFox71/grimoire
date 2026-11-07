import 'dart:io';

import 'package:grimoire/core/library_store.dart';
import 'package:grimoire/core/model.dart';

Tag theme(String name, [int up = 50, int down = 0]) => Tag(name: name, up: up, down: down, kind: TagKind.theme);
Tag trope(String name, [int up = 50, int down = 0]) => Tag(name: name, up: up, down: down, kind: TagKind.trope);

Book book(
  String id, {
  String? title,
  List<String> authors = const ['Autrice'],
  List<Tag> tags = const [],
  ReadStatus status = ReadStatus.toRead,
  int rating = 0,
}) =>
    Book(id: id, title: title ?? id, authors: [...authors], type: 'livre', addedAt: DateTime.utc(2026))
      ..tags = [...tags]
      ..status = status
      ..rating = rating;

/// Stockage en mémoire : pas d'écriture disque pendant les tests de widgets.
class MemoryStore extends LibraryStore {
  int saves = 0;
  final List<String> backups = [];
  MemoryStore() : super(Directory.systemTemp);
  @override
  Future<void> save(Library lib) async => saves++;
  @override
  Future<File> backup(String reason) async {
    backups.add(reason);
    return File('memoire');
  }
}
