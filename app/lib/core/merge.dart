import 'dart:convert';

import 'model.dart';

class MergeResult {
  final Library merged;
  final int changedOnA;
  final int changedOnB;
  MergeResult(this.merged, this.changedOnA, this.changedOnB);
}

/// Champs JSON couverts par chaque groupe horodaté.
const _groupKeys = <String, List<String>>{
  'status': ['status', 'readAt'],
  'rating': ['rating'],
  'comment': ['comment'],
  'tags': ['manualAdded', 'manualRemoved'],
  'deleted': ['deleted'],
  'booknode': [
    'booknodeId', 'url', 'title', 'authors', 'type', 'series', 'volume', 'summary', 'coverUrl', 'tags',
    'lastBooknodeList',
  ],
};

Map<String, DateTime> _maxMap(Map<String, DateTime> x, Map<String, DateTime> y) {
  final r = {...x};
  y.forEach((k, v) {
    final cur = r[k];
    if (cur == null || v.isAfter(cur)) r[k] = v;
  });
  return r;
}

Book _mergeBook(Book a, Book b) {
  final ja = a.toJson();
  final jb = b.toJson();
  final out = Map<String, dynamic>.from(ja);
  for (final g in fieldGroups) {
    final ta = a.updatedAt[g];
    final tb = b.updatedAt[g];
    final bWins = tb != null && (ta == null || tb.isAfter(ta));
    if (bWins) {
      for (final k in _groupKeys[g]!) {
        out[k] = jb[k];
      }
    }
  }
  final m = Book.fromJson(out);
  m.updatedAt = _maxMap(a.updatedAt, b.updatedAt);
  m.userEditedAt = _maxMap(a.userEditedAt, b.userEditedAt);
  return m;
}

/// Fusionne la bibliothèque du PC ([a], gagne les égalités) et celle du téléphone ([b]).
/// Ne modifie pas les entrées.
MergeResult mergeLibraries(Library a, Library b) {
  final merged = Library()
    ..lastImportAt = switch ((a.lastImportAt, b.lastImportAt)) {
      (null, final y) => y,
      (final x, null) => x,
      (final x?, final y?) => y.isAfter(x) ? y : x,
    };
  var changedOnA = 0;
  var changedOnB = 0;
  final ids = {...a.books.keys, ...b.books.keys};
  for (final id in ids) {
    final ba = a.books[id];
    final bb = b.books[id];
    final Book m;
    if (ba == null) {
      m = bb!.copy();
    } else if (bb == null) {
      m = ba.copy();
    } else {
      m = _mergeBook(ba, bb);
    }
    merged.books[id] = m;
    final enc = jsonEncode(m.toJson());
    if (ba == null || jsonEncode(ba.toJson()) != enc) changedOnA++;
    if (bb == null || jsonEncode(bb.toJson()) != enc) changedOnB++;
  }
  return MergeResult(merged, changedOnA, changedOnB);
}
