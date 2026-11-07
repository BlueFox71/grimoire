import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/model.dart';

Book roundTrip(Book b) => Book.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);

void main() {
  test('book json round-trip keeps every field', () {
    final t = DateTime.utc(2026, 11, 7, 20, 30);
    final b = Book(
      id: 'bn:03477053',
      title: 'Fourth Wing',
      authors: ['Rebecca Yarros'],
      type: 'livre',
      addedAt: DateTime.utc(2024, 1, 15),
    )
      ..booknodeId = '03477053'
      ..url = 'https://booknode.com/fourth_wing_03477053'
      ..series = 'The Empyrean'
      ..volume = 1
      ..summary = 'Rien ne prédestinait Violet'
      ..coverUrl = 'https://cdn1.booknode.com/x.jpg'
      ..tags = [
        const Tag(name: 'Dragons', up: 171, down: 1, kind: TagKind.theme),
        const Tag(name: 'Found family', up: 20, down: 1, kind: TagKind.trope),
      ]
      ..manualAdded = {'trope:Fae'}
      ..manualRemoved = {'Guerre'}
      ..status = ReadStatus.read
      ..rating = 4
      ..comment = 'génial'
      ..readAt = t
      ..lastBooknodeList = 'or'
      ..deleted = false
      ..updatedAt = {'rating': t}
      ..userEditedAt = {'rating': t};

    final r = roundTrip(b);
    expect(r.id, b.id);
    expect(r.booknodeId, '03477053');
    expect(r.url, b.url);
    expect(r.title, 'Fourth Wing');
    expect(r.authors, ['Rebecca Yarros']);
    expect(r.type, 'livre');
    expect(r.series, 'The Empyrean');
    expect(r.volume, 1);
    expect(r.summary, b.summary);
    expect(r.coverUrl, b.coverUrl);
    expect(r.tags, b.tags);
    expect(r.manualAdded, {'trope:Fae'});
    expect(r.manualRemoved, {'Guerre'});
    expect(r.status, ReadStatus.read);
    expect(r.rating, 4);
    expect(r.comment, 'génial');
    expect(r.readAt, t);
    expect(r.addedAt, DateTime.utc(2024, 1, 15));
    expect(r.lastBooknodeList, 'or');
    expect(r.deleted, false);
    expect(r.updatedAt, {'rating': t});
    expect(r.userEditedAt, {'rating': t});
  });

  test('library visible excludes deleted', () {
    final lib = Library();
    lib.books['a'] = Book(id: 'a', title: 'A', authors: [], type: 'livre', addedAt: DateTime.utc(2026));
    lib.books['b'] = Book(id: 'b', title: 'B', authors: [], type: 'livre', addedAt: DateTime.utc(2026))..deleted = true;
    expect(lib.visible.length, 1);
    final r = Library.fromJson(jsonDecode(jsonEncode(lib.toJson())) as Map<String, dynamic>);
    expect(r.books.length, 2);
    expect(r.visible.single.id, 'a');
  });

  test('fromJson tolerates missing optional fields', () {
    final b = Book.fromJson({
      'id': 'local:x',
      'title': 'T',
      'authors': [],
      'type': 'livre',
      'addedAt': '2026-01-01T00:00:00Z',
    });
    expect(b.status, ReadStatus.toRead);
    expect(b.rating, 0);
    expect(b.tags, isEmpty);
    expect(b.updatedAt, isEmpty);
    expect(b.userEditedAt, isEmpty);
    expect(b.comment, '');
  });
}
