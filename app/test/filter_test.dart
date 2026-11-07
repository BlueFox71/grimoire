import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/filter.dart';
import 'package:grimoire/core/model.dart';

import 'test_helpers.dart';

void main() {
  final a = book('a', title: 'Alpha', tags: [theme('Romantasy'), trope('Fae')]);
  final b = book('b', title: 'Beta', tags: [theme('Romantasy')]);
  final c = book('c', title: 'Gamma', tags: [theme('Romantasy'), trope('Fae')], status: ReadStatus.read, rating: 4);

  test('filterBooks AND logic', () {
    expect(filterBooks([a, b, c], FilterState(tags: {'Romantasy', 'Fae'})).map((x) => x.id), ['a']);
    expect(
      filterBooks([a, b, c], FilterState(tags: {'Romantasy', 'Fae'}, status: StatusFilter.all)).map((x) => x.id),
      ['a', 'c'],
    );
  });

  test('filterBooks default shows only to-read, sorted by title', () {
    expect(filterBooks([b, c, a], FilterState()).map((x) => x.id), ['a', 'b']);
  });

  test('filterBooks hides deleted books', () {
    final d = book('d', title: 'Delta')..deleted = true;
    expect(filterBooks([a, d], FilterState()).map((x) => x.id), ['a']);
  });

  test('filterBooks query matches author', () {
    final y = book('y', title: 'Fourth Wing', authors: ['Rebecca Yarros']);
    expect(filterBooks([a, y], FilterState(query: 'yarros')).map((x) => x.id), ['y']);
    expect(filterBooks([a, y], FilterState(query: 'FOURTH')).map((x) => x.id), ['y']);
  });

  test('chipCounts sorted by count then name', () {
    final x = book('x', tags: [theme('Romantasy')]);
    expect(
      chipCounts([a, b, x, c], StatusFilter.toRead).map((e) => '${e.key}:${e.value}'),
      ['Romantasy:3', 'Fae:1'],
    );
  });
}
