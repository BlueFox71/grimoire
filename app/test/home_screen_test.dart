import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/library_controller.dart';
import 'package:grimoire/core/library_store.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/ui/home_screen.dart';
import 'package:grimoire/ui/theme.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Future<LibraryController> controllerWith(List<Book> books) async {
  final dir = Directory.systemTemp.createTempSync('grimoire_home');
  final lib = Library();
  for (final b in books) {
    lib.books[b.id] = b;
  }
  return LibraryController(LibraryStore(dir), initial: lib);
}

Widget app(LibraryController c) => ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: grimoireLight(), home: const HomeScreen()),
    );

void main() {
  final books = [
    book('a', title: 'Fourth Wing', authors: ['Rebecca Yarros'], tags: [theme('Romantasy'), trope('Fae')]),
    book('b', title: 'Le Prince Cruel', authors: ['Holly Black'], tags: [theme('Romantasy')]),
    book('c', title: 'Dracula', authors: ['Bram Stoker'], tags: [theme('Vampires')], status: ReadStatus.read, rating: 4),
  ];

  testWidgets('shows to-read books and count', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    expect(find.text('2 livres correspondent'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsOneWidget);
    expect(find.text('Dracula'), findsNothing);
  });

  testWidgets('tapping two chips keeps books having both', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.tap(find.widgetWithText(FilterChip, 'Romantasy'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Fae'));
    await tester.pump();
    expect(find.text('1 livre correspond'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsOneWidget);
    expect(find.text('Le Prince Cruel'), findsNothing);
  });

  testWidgets('search filters by author', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.enterText(find.byType(TextField), 'holly');
    await tester.pump();
    expect(find.text('Le Prince Cruel'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsNothing);
  });

  testWidgets('status Lus shows read books with stars', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.tap(find.text('Lus'));
    await tester.pump();
    expect(find.text('Dracula'), findsOneWidget);
    expect(find.text('★★★★☆'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsNothing);
  });

  testWidgets('books with few tags show the à compléter badge', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    expect(find.text('à compléter'), findsNWidgets(2));
  });

  testWidgets('selected chip label is light on the accent colour (readable)', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.tap(find.widgetWithText(FilterChip, 'Fae'));
    await tester.pump();
    final label = tester.widget<DefaultTextStyle>(
      find.ancestor(of: find.text('Fae'), matching: find.byType(DefaultTextStyle)).first,
    );
    expect(label.style.color, Colors.white);
  });
}
