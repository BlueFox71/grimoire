import 'model.dart';

/// Un thème ou trope Booknode est retenu si personne ne le conteste, ou, s'il est contesté,
/// si les lecteurs votent nettement pour (au moins 3 pour, et deux fois plus de pour que de contre).
/// Beaucoup de livres peu lus n'ont que 0 à 2 votes par thème : on les garde tant qu'il n'y a pas de contre.
const minUpVotes = 3;
const upToDownRatio = 2;

/// En dessous de ce nombre d'étiquettes affichées, le livre est « à compléter ».
const minDisplayedTags = 3;

bool isKept(Tag t) => t.down == 0 || (t.up >= minUpVotes && t.up >= upToDownRatio * t.down);

/// Étiquettes affichées : retenues, moins les retirées par Jules, plus ses ajouts.
/// Thèmes avant tropes, puis votes décroissants.
List<Tag> displayTags(Book b) {
  final seen = <String>{};
  final result = <Tag>[];
  for (final t in b.tags) {
    if (isKept(t) && !b.manualRemoved.contains(t.name) && seen.add(t.name)) result.add(t);
  }
  for (final m in b.manualAdded) {
    final i = m.indexOf(':');
    final kind = i > 0 && m.substring(0, i) == 'trope' ? TagKind.trope : TagKind.theme;
    final name = i > 0 ? m.substring(i + 1) : m;
    if (seen.add(name)) result.add(Tag(name: name, up: 0, down: 0, kind: kind));
  }
  result.sort((x, y) {
    final k = x.kind.index.compareTo(y.kind.index);
    return k != 0 ? k : y.up.compareTo(x.up);
  });
  return result;
}

bool needsCompletion(Book b) => displayTags(b).length < minDisplayedTags;

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', 'ø': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y', 'ñ': 'n',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  '’': "'", '‘': "'",
};

/// Minuscules, sans accents, espaces réduits.
String normalize(String s) {
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_accents[ch] ?? ch);
  }
  return buf.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}
