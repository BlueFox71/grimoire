import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'model.dart';

/// Recherche d'un livre à ajouter : Google Books, puis Open Library en secours.
class BookCandidate {
  final String title;
  final List<String> authors;
  final String? summary;
  final String? coverUrl;
  final String? series;

  BookCandidate({required this.title, required this.authors, this.summary, this.coverUrl, this.series});
}

class BookSearchException implements Exception {
  final String message;
  BookSearchException(this.message);
  @override
  String toString() => message;
}

List<BookCandidate> parseGoogleBooks(Map<String, dynamic> json) => [
      for (final item in (json['items'] as List? ?? const []))
        if ((item as Map)['volumeInfo'] case final Map v when v['title'] is String)
          BookCandidate(
            title: v['subtitle'] is String ? '${v['title']} : ${v['subtitle']}' : v['title'] as String,
            authors: [for (final a in (v['authors'] as List? ?? const [])) a as String],
            summary: v['description'] as String?,
            coverUrl: (v['imageLinks'] as Map?)?['thumbnail'] is String
                ? ((v['imageLinks'] as Map)['thumbnail'] as String).replaceFirst('http://', 'https://')
                : null,
          ),
    ];

List<BookCandidate> parseOpenLibrary(Map<String, dynamic> json) => [
      for (final d in (json['docs'] as List? ?? const []))
        if ((d as Map)['title'] is String)
          BookCandidate(
            title: d['title'] as String,
            authors: [for (final a in (d['author_name'] as List? ?? const [])) a as String],
            coverUrl: d['cover_i'] is num ? 'https://covers.openlibrary.org/b/id/${d['cover_i']}-M.jpg' : null,
          ),
    ];

Future<List<BookCandidate>> searchBooks(String query, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    try {
      final res = await c
          .get(Uri.https('www.googleapis.com', '/books/v1/volumes', {
            'q': query,
            'langRestrict': 'fr',
            'maxResults': '20',
          }))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final found = parseGoogleBooks(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        if (found.isNotEmpty) return found;
      }
    } catch (_) {}
    try {
      final res = await c
          .get(Uri.https('openlibrary.org', '/search.json', {
            'q': query,
            'fields': 'title,author_name,cover_i',
            'limit': '20',
          }))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return parseOpenLibrary(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      }
    } catch (_) {}
    throw BookSearchException("Pas de connexion : tu peux l'ajouter à la main.");
  } finally {
    if (client == null) c.close();
  }
}

final _rand = Random.secure();

Book candidateToBook(BookCandidate c, DateTime now) {
  final id = 'local:${now.microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 32).toRadixString(36)}';
  return Book(id: id, title: c.title, authors: [...c.authors], type: 'livre', addedAt: now)
    ..summary = c.summary
    ..coverUrl = c.coverUrl
    ..series = c.series
    ..updatedAt['booknode'] = now
    ..updatedAt['status'] = now;
}
