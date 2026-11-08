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
  'deleted': ['deleted', 'mergedInto'],
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

/// Une pierre tombale `local:` ré-identifiée en `bn:` à l'import peut encore recevoir
/// des modifications d'un téléphone qui ne connaissait que l'ancien identifiant :
/// on reporte les groupes plus récents vers le livre `bn:`.
void _forwardRekeyed(Library merged) {
  const forwarded = ['status', 'rating', 'comment', 'tags'];
  for (final src in merged.books.values) {
    final target = src.mergedInto == null ? null : merged.books[src.mergedInto];
    if (target == null) continue;
    final js = src.toJson();
    final jt = target.toJson();
    var changed = false;
    for (final g in forwarded) {
      final ts = src.updatedAt[g];
      final tt = target.updatedAt[g];
      if (ts == null || (tt != null && !ts.isAfter(tt))) continue;
      for (final k in _groupKeys[g]!) {
        jt[k] = js[k];
      }
      changed = true;
    }
    if (!changed) continue;
    final updated = Book.fromJson(jt)
      ..updatedAt = {...target.updatedAt}
      ..userEditedAt = {...target.userEditedAt};
    for (final g in forwarded) {
      final ts = src.updatedAt[g];
      final tt = target.updatedAt[g];
      if (ts != null && (tt == null || ts.isAfter(tt))) updated.updatedAt[g] = ts;
      final us = src.userEditedAt[g];
      final ut = target.userEditedAt[g];
      if (us != null && (ut == null || us.isAfter(ut))) updated.userEditedAt[g] = us;
    }
    merged.books[target.id] = updated;
  }
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
  }
  _forwardRekeyed(merged);
  var changedOnA = 0;
  var changedOnB = 0;
  for (final m in merged.books.values) {
    final enc = jsonEncode(m.toJson());
    final ba = a.books[m.id];
    final bb = b.books[m.id];
    if (ba == null || jsonEncode(ba.toJson()) != enc) changedOnA++;
    if (bb == null || jsonEncode(bb.toJson()) != enc) changedOnB++;
  }
  return MergeResult(merged, changedOnA, changedOnB);
}
