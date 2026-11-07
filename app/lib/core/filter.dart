import 'model.dart';
import 'tags.dart';

enum StatusFilter { toRead, reading, read, all }

class FilterState {
  String query;
  Set<String> tags;
  StatusFilter status;

  FilterState({this.query = '', Set<String>? tags, this.status = StatusFilter.toRead}) : tags = tags ?? {};
}

bool _statusMatches(Book b, StatusFilter s) => switch (s) {
      StatusFilter.toRead => b.status == ReadStatus.toRead,
      StatusFilter.reading => b.status == ReadStatus.reading,
      StatusFilter.read => b.status == ReadStatus.read,
      StatusFilter.all => true,
    };

List<Book> filterBooks(Iterable<Book> books, FilterState f) {
  final q = normalize(f.query);
  final result = books.where((b) {
    if (b.deleted || !_statusMatches(b, f.status)) return false;
    if (q.isNotEmpty && !normalize(b.title).contains(q) && !b.authors.any((a) => normalize(a).contains(q))) {
      return false;
    }
    if (f.tags.isNotEmpty) {
      final names = displayTags(b).map((t) => t.name).toSet();
      if (!names.containsAll(f.tags)) return false;
    }
    return true;
  }).toList();
  result.sort((x, y) => normalize(x.title).compareTo(normalize(y.title)));
  return result;
}

/// Nombre de livres (visibles, au statut donné) par étiquette affichée,
/// du plus fréquent au moins fréquent, puis par ordre alphabétique.
List<MapEntry<String, int>> chipCounts(Iterable<Book> books, StatusFilter s) {
  final counts = <String, int>{};
  for (final b in books) {
    if (b.deleted || !_statusMatches(b, s)) continue;
    for (final t in displayTags(b)) {
      counts[t.name] = (counts[t.name] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((x, y) {
      final c = y.value.compareTo(x.value);
      return c != 0 ? c : normalize(x.key).compareTo(normalize(y.key));
    });
  return entries;
}
