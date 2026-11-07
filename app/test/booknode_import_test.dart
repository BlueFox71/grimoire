import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/booknode_import.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/core/tags.dart';

Map<String, dynamic> loadExport() =>
    jsonDecode(File('test/fixtures/export_small.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> bookEntry(Map<String, dynamic> export, String title) =>
    (export['books'] as List).cast<Map<String, dynamic>>().firstWhere((b) => b['title'] == title);

final t0 = DateTime.utc(2026, 11, 7, 21);
final t1 = DateTime.utc(2026, 11, 8, 10);
final t2 = DateTime.utc(2026, 11, 9, 10);

Book byTitle(Library lib, String title) => lib.books.values.firstWhere((b) => b.title == title);

void main() {
  test('first import creates books with mapped status', () {
    final lib = Library();
    final r = applyExport(lib, loadExport(), t0);
    expect(r.added.length, 3);
    final prince = byTitle(lib, 'Le Prince Cruel');
    expect(prince.status, ReadStatus.read);
    expect(prince.rating, 4);
    expect(prince.id, 'bn:01234567');
    expect(byTitle(lib, 'Liens, Tome 1 : Un lien de fer et de feu').status, ReadStatus.reading);
    final fw = byTitle(lib, 'Fourth Wing');
    expect(fw.status, ReadStatus.toRead);
    expect(fw.series, 'The Empyrean');
    expect(fw.volume, 1);
    expect(fw.addedAt, DateTime.utc(2024, 1, 15));
    final names = displayTags(fw).map((t) => t.name);
    expect(names, contains('Dragons'));
    expect(names, contains('Ennemis à amants (Enemies to lovers)'));
    expect(names, isNot(contains('Young Adult')));
    expect(fw.tags.firstWhere((t) => t.name.startsWith('Ennemis')).kind, TagKind.trope);
    expect(lib.lastImportAt, t0);
  });

  test('list mapping covers every imported list', () {
    final export = loadExport();
    final expected = {
      'pal': (ReadStatus.toRead, 0),
      'en_cours': (ReadStatus.reading, 0),
      'diamant': (ReadStatus.read, 5),
      'or': (ReadStatus.read, 4),
      'argent': (ReadStatus.read, 3),
      'bronze': (ReadStatus.read, 2),
      'pas_apprecie': (ReadStatus.read, 1),
      'lu_aussi': (ReadStatus.read, 0),
    };
    for (final e in expected.entries) {
      final lib = Library();
      bookEntry(export, 'Fourth Wing')['list'] = e.key;
      applyExport(lib, export, t0);
      final fw = byTitle(lib, 'Fourth Wing');
      expect((fw.status, fw.rating), e.value, reason: e.key);
    }
  });

  test('reimport applies booknode list change when user did not edit', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final next = loadExport();
    bookEntry(next, 'Fourth Wing')['list'] = 'diamant';
    final r = applyExport(lib, next, t1);
    final fw = byTitle(lib, 'Fourth Wing');
    expect(fw.status, ReadStatus.read);
    expect(fw.rating, 5);
    expect(r.updated, contains('Fourth Wing'));
    expect(fw.updatedAt['status'], t1);
    expect(fw.userEditedAt, isEmpty);
  });

  test('reimport keeps user edit and reports differs', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final fw = byTitle(lib, 'Fourth Wing')
      ..status = ReadStatus.read
      ..rating = 2;
    fw.userEditedAt['rating'] = t0.add(const Duration(hours: 1));
    final next = loadExport();
    bookEntry(next, 'Fourth Wing')['list'] = 'diamant';
    final r = applyExport(lib, next, t1);
    expect(fw.rating, 2);
    expect(r.differs, contains('Fourth Wing'));
    expect(r.updated, isNot(contains('Fourth Wing')));
  });

  test('null details never erase summary or tags', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final next = loadExport();
    bookEntry(next, 'Fourth Wing')['details'] = null;
    applyExport(lib, next, t1);
    final fw = byTitle(lib, 'Fourth Wing');
    expect(fw.summary, startsWith('Rien ne prédestinait'));
    expect(fw.tags, isNotEmpty);
    expect(fw.coverUrl, isNotNull);
  });

  test('complete export removes missing book unless rated in grimoire', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final next = loadExport();
    (next['books'] as List).removeWhere((b) => b['title'] == 'Le Prince Cruel');
    final r = applyExport(lib, next, t1);
    final prince = byTitle(lib, 'Le Prince Cruel');
    expect(prince.deleted, isTrue);
    expect(prince.updatedAt['deleted'], t1);
    expect(r.removed, ['Le Prince Cruel']);

    final lib2 = Library();
    applyExport(lib2, loadExport(), t0);
    final p2 = byTitle(lib2, 'Le Prince Cruel')..comment = 'coup de cœur';
    p2.userEditedAt['comment'] = t0.add(const Duration(hours: 1));
    final r2 = applyExport(lib2, next, t1);
    expect(p2.deleted, isFalse);
    expect(r2.removed, isEmpty);
  });

  test('complete export keeps a missing book that is being read', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final next = loadExport();
    (next['books'] as List).removeWhere((b) => (b['title'] as String).startsWith('Liens'));
    applyExport(lib, next, t1);
    expect(byTitle(lib, 'Liens, Tome 1 : Un lien de fer et de feu').deleted, isFalse);
  });

  test('partial export removes nothing', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    final next = loadExport()..['complete'] = false;
    (next['books'] as List).removeWhere((b) => b['title'] == 'Le Prince Cruel');
    final r = applyExport(lib, next, t1);
    expect(byTitle(lib, 'Le Prince Cruel').deleted, isFalse);
    expect(r.removed, isEmpty);
  });

  test('google books book is matched by normalized title and author', () {
    final lib = Library();
    final local = Book(id: 'local:x', title: 'le prince cruel', authors: ['holly black'], type: 'livre', addedAt: t0)
      ..status = ReadStatus.reading;
    local.userEditedAt['status'] = t0;
    lib.books[local.id] = local;
    lib.lastImportAt = DateTime.utc(2026, 1, 1);
    applyExport(lib, loadExport(), t1);
    final princes = lib.books.values.where((b) => normalize(b.title) == 'le prince cruel').toList();
    expect(princes.length, 1);
    expect(princes.single.id, 'bn:01234567');
    expect(princes.single.booknodeId, '01234567');
    expect(princes.single.status, ReadStatus.reading);
    expect(princes.single.summary, startsWith('Jude'));
    expect(lib.books.containsKey('local:x'), isFalse);
  });

  test('deleted book is not resurrected', () {
    final lib = Library();
    applyExport(lib, loadExport(), t0);
    byTitle(lib, 'Fourth Wing').deleted = true;
    final next = loadExport();
    bookEntry(next, 'Fourth Wing')['list'] = 'diamant';
    final r = applyExport(lib, next, t2);
    final fw = byTitle(lib, 'Fourth Wing');
    expect(fw.deleted, isTrue);
    expect(fw.status, ReadStatus.toRead);
    expect(r.added, isNot(contains('Fourth Wing')));
  });

  test('rejects unknown format', () {
    expect(() => applyExport(Library(), {'format': 'autre', 'version': 1, 'books': []}, t0), throwsFormatException);
    expect(
      () => applyExport(Library(), {'format': 'grimoire-booknode-export', 'version': 2, 'books': []}, t0),
      throwsFormatException,
    );
  });
}
