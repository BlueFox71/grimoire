import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/library_store.dart';
import 'package:grimoire/core/model.dart';

import 'test_helpers.dart';

Library libWith(String id) => Library()..books[id] = book(id);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('grimoire_store'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('save then load round-trips', () async {
    final store = LibraryStore(dir);
    await store.save(libWith('a'));
    final lib = await store.load();
    expect(lib.books.keys, ['a']);
  });

  test('load falls back to bak when main file is corrupt', () async {
    final store = LibraryStore(dir);
    await store.save(libWith('A'));
    await store.save(libWith('B'));
    File('${dir.path}/grimoire.json').writeAsStringSync('{oops');
    final lib = await store.load();
    expect(lib.books.keys, ['A']);
  });

  test('load with both files corrupt keeps the corrupt file aside and starts empty', () async {
    final store = LibraryStore(dir);
    File('${dir.path}/grimoire.json').writeAsStringSync('{oops');
    File('${dir.path}/grimoire.json.bak').writeAsStringSync('nope');
    final lib = await store.load();
    expect(lib.books, isEmpty);
    expect(dir.listSync().any((f) => f.path.contains('grimoire.json.corrompu-')), isTrue);
  });

  test('load with no file returns empty library', () async {
    final lib = await LibraryStore(dir).load();
    expect(lib.books, isEmpty);
  });

  test('backup keeps 20 most recent', () async {
    final store = LibraryStore(dir);
    await store.save(libWith('a'));
    for (var i = 0; i < 22; i++) {
      await store.backup('test$i');
    }
    expect(Directory('${dir.path}/backups').listSync().length, 20);
  });
}
