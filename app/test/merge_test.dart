import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/merge.dart';
import 'package:grimoire/core/model.dart';

import 'test_helpers.dart';

final t1 = DateTime.utc(2026, 11, 1);
final t2 = DateTime.utc(2026, 11, 2);
final t3 = DateTime.utc(2026, 11, 3);

(Library, Library) pair() {
  final a = Library()..books['x'] = book('x');
  final b = Library()..books['x'] = book('x');
  return (a, b);
}

void main() {
  test('different fields edited on each side both survive', () {
    final (a, b) = pair();
    a.books['x']!
      ..rating = 5
      ..updatedAt['rating'] = t2
      ..userEditedAt['rating'] = t2;
    b.books['x']!
      ..comment = 'génial'
      ..updatedAt['comment'] = t3;
    final r = mergeLibraries(a, b);
    final m = r.merged.books['x']!;
    expect(m.rating, 5);
    expect(m.comment, 'génial');
    expect(m.updatedAt, {'rating': t2, 'comment': t3});
    expect(m.userEditedAt, {'rating': t2});
    expect(r.changedOnA, 1);
    expect(r.changedOnB, 1);
  });

  test('same field: most recent wins', () {
    final (a, b) = pair();
    a.books['x']!
      ..rating = 3
      ..updatedAt['rating'] = t2;
    b.books['x']!
      ..rating = 4
      ..updatedAt['rating'] = t3;
    expect(mergeLibraries(a, b).merged.books['x']!.rating, 4);
  });

  test('tie goes to PC side', () {
    final (a, b) = pair();
    a.books['x']!
      ..rating = 3
      ..updatedAt['rating'] = t2;
    b.books['x']!
      ..rating = 4
      ..updatedAt['rating'] = t2;
    final r = mergeLibraries(a, b);
    expect(r.merged.books['x']!.rating, 3);
    expect(r.changedOnA, 0);
    expect(r.changedOnB, 1);
  });

  test('status group carries readAt', () {
    final (a, b) = pair();
    b.books['x']!
      ..status = ReadStatus.read
      ..readAt = t3
      ..updatedAt['status'] = t3;
    final m = mergeLibraries(a, b).merged.books['x']!;
    expect(m.status, ReadStatus.read);
    expect(m.readAt, t3);
  });

  test('tombstone newer than edit wins', () {
    final (a, b) = pair();
    a.books['x']!
      ..deleted = true
      ..updatedAt['deleted'] = t3;
    b.books['x']!
      ..rating = 2
      ..updatedAt['rating'] = t2;
    final m = mergeLibraries(a, b).merged.books['x']!;
    expect(m.deleted, isTrue);
  });

  test('groups are independent', () {
    final (a, b) = pair();
    a.books['x']!
      ..deleted = true
      ..updatedAt['deleted'] = t2;
    b.books['x']!
      ..rating = 4
      ..updatedAt['rating'] = t3;
    final m = mergeLibraries(a, b).merged.books['x']!;
    expect(m.deleted, isTrue);
    expect(m.rating, 4);
  });

  test('booknode and manual tag groups merge separately', () {
    final (a, b) = pair();
    a.books['x']!
      ..tags = [theme('Dragons')]
      ..summary = 'résumé'
      ..updatedAt['booknode'] = t2;
    b.books['x']!
      ..manualAdded = {'trope:Fae'}
      ..updatedAt['tags'] = t3;
    final m = mergeLibraries(a, b).merged.books['x']!;
    expect(m.tags.map((t) => t.name), ['Dragons']);
    expect(m.summary, 'résumé');
    expect(m.manualAdded, {'trope:Fae'});
  });

  test('books only on one side are copied and counted', () {
    final a = Library()..books['pc'] = book('pc');
    final b = Library()..books['tel'] = book('tel');
    final r = mergeLibraries(a, b);
    expect(r.merged.books.keys.toSet(), {'pc', 'tel'});
    expect(r.changedOnA, 1);
    expect(r.changedOnB, 1);
  });

  test('lastImportAt is the most recent and inputs are not mutated', () {
    final a = Library()..lastImportAt = t1;
    final b = Library()..lastImportAt = t2;
    a.books['x'] = book('x')..rating = 1..updatedAt['rating'] = t1;
    b.books['x'] = book('x')..rating = 5..updatedAt['rating'] = t2;
    final r = mergeLibraries(a, b);
    expect(r.merged.lastImportAt, t2);
    expect(a.books['x']!.rating, 1);
  });

  test('phone edits on a local id re-keyed by the pc are forwarded to the new book', () {
    final pc = Library()
      ..books['local:x'] = (book('local:x')
        ..deleted = true
        ..mergedInto = 'bn:1'
        ..updatedAt['deleted'] = t2)
      ..books['bn:1'] = (book('bn:1')..updatedAt['booknode'] = t2);
    final phone = Library()
      ..books['local:x'] = (book('local:x')
        ..rating = 5
        ..comment = 'top'
        ..updatedAt['rating'] = t3
        ..userEditedAt['rating'] = t3
        ..updatedAt['comment'] = t3);
    final m = mergeLibraries(pc, phone).merged;
    expect(m.books['bn:1']!.rating, 5);
    expect(m.books['bn:1']!.comment, 'top');
    expect(m.books['bn:1']!.userEditedAt['rating'], t3);
    expect(m.books['local:x']!.deleted, isTrue);
  });
}
