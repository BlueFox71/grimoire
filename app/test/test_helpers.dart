import 'package:grimoire/core/model.dart';

Tag theme(String name, [int up = 50, int down = 0]) => Tag(name: name, up: up, down: down, kind: TagKind.theme);
Tag trope(String name, [int up = 50, int down = 0]) => Tag(name: name, up: up, down: down, kind: TagKind.trope);

Book book(
  String id, {
  String? title,
  List<String> authors = const ['Autrice'],
  List<Tag> tags = const [],
  ReadStatus status = ReadStatus.toRead,
  int rating = 0,
}) =>
    Book(id: id, title: title ?? id, authors: [...authors], type: 'livre', addedAt: DateTime.utc(2026))
      ..tags = [...tags]
      ..status = status
      ..rating = rating;
