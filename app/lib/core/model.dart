/// Modèle de données de Grimoire : livres, étiquettes, bibliothèque.
library;

enum ReadStatus { toRead, reading, read }

enum TagKind { theme, trope }

/// Groupes de champs horodatés (clés de [Book.updatedAt] et [Book.userEditedAt]).
/// - status : status + readAt
/// - rating, comment, deleted
/// - tags : manualAdded + manualRemoved (retouches de Jules)
/// - booknode : titre, auteurs, type, série, tome, résumé, couverture, tags, url, lastBooknodeList
const fieldGroups = ['status', 'rating', 'comment', 'tags', 'deleted', 'booknode'];

class Tag {
  final String name;
  final int up;
  final int down;
  final TagKind kind;

  const Tag({required this.name, required this.up, required this.down, required this.kind});

  Map<String, dynamic> toJson() => {'name': name, 'up': up, 'down': down, 'kind': kind.name};

  factory Tag.fromJson(Map<String, dynamic> j) => Tag(
        name: j['name'] as String,
        up: (j['up'] as num?)?.toInt() ?? 0,
        down: (j['down'] as num?)?.toInt() ?? 0,
        kind: TagKind.values.byName((j['kind'] as String?) ?? 'theme'),
      );

  @override
  bool operator ==(Object other) =>
      other is Tag && other.name == name && other.up == up && other.down == down && other.kind == kind;

  @override
  int get hashCode => Object.hash(name, up, down, kind);

  @override
  String toString() => 'Tag($name, $up/$down, ${kind.name})';
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toUtc();
String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

Map<String, DateTime> _dateMap(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries) e.key as String: DateTime.parse(e.value as String).toUtc(),
    };
Map<String, String> _isoMap(Map<String, DateTime> m) => {for (final e in m.entries) e.key: e.value.toUtc().toIso8601String()};

class Book {
  String id;
  String? booknodeId;
  String? url;
  String title;
  List<String> authors;
  String type;
  String? series;
  num? volume;
  String? summary;
  String? coverUrl;
  List<Tag> tags = [];
  Set<String> manualAdded = {};
  Set<String> manualRemoved = {};
  ReadStatus status = ReadStatus.toRead;
  int rating = 0;
  String comment = '';
  DateTime? readAt;
  DateTime addedAt;
  String? lastBooknodeList;
  bool deleted = false;
  Map<String, DateTime> updatedAt = {};
  Map<String, DateTime> userEditedAt = {};

  Book({required this.id, required this.title, required this.authors, required this.type, required this.addedAt});

  Book copy() => Book.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'booknodeId': booknodeId,
        'url': url,
        'title': title,
        'authors': authors,
        'type': type,
        'series': series,
        'volume': volume,
        'summary': summary,
        'coverUrl': coverUrl,
        'tags': [for (final t in tags) t.toJson()],
        'manualAdded': manualAdded.toList(),
        'manualRemoved': manualRemoved.toList(),
        'status': status.name,
        'rating': rating,
        'comment': comment,
        'readAt': _iso(readAt),
        'addedAt': _iso(addedAt),
        'lastBooknodeList': lastBooknodeList,
        'deleted': deleted,
        'updatedAt': _isoMap(updatedAt),
        'userEditedAt': _isoMap(userEditedAt),
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        authors: [for (final a in (j['authors'] as List? ?? const [])) a as String],
        type: (j['type'] as String?) ?? 'livre',
        addedAt: _date(j['addedAt']) ?? DateTime.utc(1970),
      )
        ..booknodeId = j['booknodeId'] as String?
        ..url = j['url'] as String?
        ..series = j['series'] as String?
        ..volume = j['volume'] as num?
        ..summary = j['summary'] as String?
        ..coverUrl = j['coverUrl'] as String?
        ..tags = [for (final t in (j['tags'] as List? ?? const [])) Tag.fromJson(t as Map<String, dynamic>)]
        ..manualAdded = {for (final s in (j['manualAdded'] as List? ?? const [])) s as String}
        ..manualRemoved = {for (final s in (j['manualRemoved'] as List? ?? const [])) s as String}
        ..status = ReadStatus.values.byName((j['status'] as String?) ?? 'toRead')
        ..rating = (j['rating'] as num?)?.toInt() ?? 0
        ..comment = (j['comment'] as String?) ?? ''
        ..readAt = _date(j['readAt'])
        ..lastBooknodeList = j['lastBooknodeList'] as String?
        ..deleted = (j['deleted'] as bool?) ?? false
        ..updatedAt = _dateMap(j['updatedAt'])
        ..userEditedAt = _dateMap(j['userEditedAt']);
}

class Library {
  int version = 1;
  DateTime? lastImportAt;
  Map<String, Book> books = {};

  Library();

  Iterable<Book> get visible => books.values.where((b) => !b.deleted);

  Library copy() => Library.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'version': version,
        'lastImportAt': _iso(lastImportAt),
        'books': [for (final b in books.values) b.toJson()],
      };

  factory Library.fromJson(Map<String, dynamic> j) {
    final lib = Library()
      ..version = (j['version'] as num?)?.toInt() ?? 1
      ..lastImportAt = _date(j['lastImportAt']);
    for (final b in (j['books'] as List? ?? const [])) {
      final book = Book.fromJson(b as Map<String, dynamic>);
      lib.books[book.id] = book;
    }
    return lib;
  }
}
