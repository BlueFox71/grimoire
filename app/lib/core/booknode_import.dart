import 'model.dart';
import 'tags.dart';

const exportFormat = 'grimoire-booknode-export';
const exportVersion = 1;

/// Liste Booknode → (statut, note).
const listMapping = <String, (ReadStatus, int)>{
  'pal': (ReadStatus.toRead, 0),
  'en_cours': (ReadStatus.reading, 0),
  'diamant': (ReadStatus.read, 5),
  'or': (ReadStatus.read, 4),
  'argent': (ReadStatus.read, 3),
  'bronze': (ReadStatus.read, 2),
  'pas_apprecie': (ReadStatus.read, 1),
  'lu_aussi': (ReadStatus.read, 0),
};

class ImportReport {
  final List<String> added = [];
  final List<String> updated = [];
  final List<String> removed = [];
  final List<String> differs = [];
}

bool _after(DateTime? d, DateTime? ref) => d != null && (ref == null || d.isAfter(ref));

/// Applique un export Booknode à la bibliothèque (voir la conception, §3).
ImportReport applyExport(Library lib, Map<String, dynamic> export, DateTime now) {
  if (export['format'] != exportFormat || export['version'] != exportVersion) {
    throw const FormatException("Ce fichier n'est pas un export Booknode de Grimoire.");
  }
  final report = ImportReport();
  final lastImport = lib.lastImportAt;
  final seenIds = <String>{};

  for (final raw in (export['books'] as List? ?? const [])) {
    final e = raw as Map<String, dynamic>;
    final bnId = e['booknodeId'] as String;
    final list = e['list'] as String;
    final mapping = listMapping[list];
    if (mapping == null) continue;
    seenIds.add(bnId);
    final title = e['title'] as String;
    final authors = [for (final a in (e['authors'] as List? ?? const [])) a as String];

    var b = lib.books['bn:$bnId'];
    var created = false;
    if (b == null) {
      final nt = normalize(title);
      final na = authors.isEmpty ? '' : normalize(authors.first);
      for (final candidate in lib.books.values) {
        if (candidate.booknodeId == null &&
            !candidate.deleted &&
            normalize(candidate.title) == nt &&
            (candidate.authors.isEmpty ? '' : normalize(candidate.authors.first)) == na) {
          b = candidate;
          break;
        }
      }
      if (b != null) {
        // Pierre tombale à l'ancien identifiant : un téléphone qui a encore
        // ce livre sous `local:` ne le fera pas réapparaître à la synchro.
        lib.books[b.id] = b.copy()
          ..deleted = true
          ..updatedAt['deleted'] = now;
        b.id = 'bn:$bnId';
        lib.books[b.id] = b;
      }
    }
    if (b == null) {
      created = true;
      b = Book(
        id: 'bn:$bnId',
        title: title,
        authors: authors,
        type: (e['type'] as String?) ?? 'livre',
        addedAt: DateTime.tryParse('${e['addedAt']}T00:00:00Z') ?? now,
      )
        ..status = mapping.$1
        ..rating = mapping.$2;
      lib.books[b.id] = b;
      b.updatedAt['status'] = now;
      b.updatedAt['rating'] = now;
      report.added.add(title);
    }
    if (b.deleted) continue;

    // Données Booknode.
    b.booknodeId = bnId;
    b.url = (e['url'] as String?) ?? b.url;
    b.title = title;
    if (authors.isNotEmpty) b.authors = authors;
    b.type = (e['type'] as String?) ?? b.type;
    final d = e['details'] as Map<String, dynamic>?;
    if (d != null) {
      b.coverUrl = (d['coverUrl'] as String?) ?? b.coverUrl;
      b.summary = (d['summary'] as String?) ?? b.summary;
      b.series = (d['series'] as String?) ?? b.series;
      b.volume = (d['volume'] as num?) ?? b.volume;
      final themes = [
        for (final t in (d['themes'] as List? ?? const []))
          Tag.fromJson({...(t as Map<String, dynamic>), 'kind': 'theme'}),
      ];
      final tropes = [
        for (final t in (d['tropes'] as List? ?? const []))
          Tag.fromJson({...(t as Map<String, dynamic>), 'kind': 'trope'}),
      ];
      if (themes.isNotEmpty || tropes.isNotEmpty) b.tags = [...themes, ...tropes];
    }

    // Statut / note.
    if (!created && list != b.lastBooknodeList) {
      final userEdited = _after(b.userEditedAt['status'], lastImport) || _after(b.userEditedAt['rating'], lastImport);
      if (userEdited) {
        if (b.status != mapping.$1 || b.rating != mapping.$2) report.differs.add(title);
      } else if (b.status != mapping.$1 || b.rating != mapping.$2) {
        if (b.status != mapping.$1) {
          b.status = mapping.$1;
          b.readAt = mapping.$1 == ReadStatus.read ? now : null;
          b.updatedAt['status'] = now;
        }
        if (b.rating != mapping.$2) {
          b.rating = mapping.$2;
          b.updatedAt['rating'] = now;
        }
        report.updated.add(title);
      }
    }
    b.lastBooknodeList = list;
    b.updatedAt['booknode'] = now;
  }

  if (export['complete'] == true) {
    for (final b in lib.books.values) {
      if (b.deleted || b.booknodeId == null || seenIds.contains(b.booknodeId)) continue;
      final keep = b.status == ReadStatus.reading ||
          (b.status == ReadStatus.read && (b.userEditedAt['rating'] != null || b.userEditedAt['comment'] != null));
      if (keep) continue;
      b.deleted = true;
      b.updatedAt['deleted'] = now;
      report.removed.add(b.title);
    }
  }

  lib.lastImportAt = now;
  return report;
}
