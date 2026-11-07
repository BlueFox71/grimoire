import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/google_books.dart';
import 'package:grimoire/core/model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parseGoogleBooks reads title, subtitle, authors and https cover', () {
    final c = parseGoogleBooks(fixture('google_books_prince_cruel.json'));
    expect(c.length, 2);
    expect(c.first.title, "Le Peuple de l'air : Le Prince cruel");
    expect(c.first.authors, ['Holly Black']);
    expect(c.first.summary, startsWith('Jude'));
    expect(c.first.coverUrl, startsWith('https://books.google.com/'));
    expect(c[1].authors, isEmpty);
    expect(c[1].coverUrl, isNull);
  });

  test('parseGoogleBooks without items is empty', () {
    expect(parseGoogleBooks({'kind': 'books#volumes', 'totalItems': 0}), isEmpty);
  });

  test('parseOpenLibrary reads real response', () {
    final c = parseOpenLibrary(fixture('openlibrary_prince_cruel.json'));
    expect(c, isNotEmpty);
    expect(c.first.title, 'The Cruel Prince');
    expect(c.first.authors, ['Holly Black']);
    expect(c.first.coverUrl, 'https://covers.openlibrary.org/b/id/8361789-M.jpg');
  });

  test('searchBooks uses google books first', () async {
    final client = MockClient((req) async {
      expect(req.url.host, 'www.googleapis.com');
      expect(req.url.queryParameters['q'], 'prince cruel');
      return http.Response.bytes(utf8.encode(jsonEncode(fixture('google_books_prince_cruel.json'))), 200);
    });
    final c = await searchBooks('prince cruel', client: client);
    expect(c.first.authors, ['Holly Black']);
  });

  test('searchBooks falls back to open library when google refuses', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'www.googleapis.com') return http.Response('{"error":{"code":429}}', 429);
      expect(req.url.host, 'openlibrary.org');
      return http.Response.bytes(utf8.encode(jsonEncode(fixture('openlibrary_prince_cruel.json'))), 200);
    });
    final c = await searchBooks('prince cruel', client: client);
    expect(c.first.title, 'The Cruel Prince');
  });

  test('searchBooks throws when both services fail', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    await expectLater(searchBooks('x', client: client), throwsA(isA<BookSearchException>()));
  });

  test('candidateToBook creates a local to-read book', () {
    final now = DateTime.utc(2026, 11, 7);
    final b = candidateToBook(
      BookCandidate(title: 'Le Prince cruel', authors: ['Holly Black'], coverUrl: 'https://x/y.jpg'),
      now,
    );
    expect(b.id, startsWith('local:'));
    expect(b.booknodeId, isNull);
    expect(b.status, ReadStatus.toRead);
    expect(b.coverUrl, 'https://x/y.jpg');
    expect(b.addedAt, now);
    expect(b.updatedAt['booknode'], now);
    expect(candidateToBook(BookCandidate(title: 'A', authors: []), now).id, isNot(b.id));
  });
}
