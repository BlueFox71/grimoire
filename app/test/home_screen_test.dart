import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/library_controller.dart';
import 'package:grimoire/core/library_store.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/ui/home_screen.dart';
import 'package:grimoire/ui/pinned_tags.dart';
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

Widget app(LibraryController c, {PinnedTags? pins}) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: c),
        ChangeNotifierProvider.value(value: pins ?? PinnedTags()),
      ],
      child: MaterialApp(theme: grimoireLight(), home: const HomeScreen()),
    );

void main() {
  final books = [
    book('a', title: 'Fourth Wing', authors: ['Rebecca Yarros'], tags: [theme('Romantasy'), trope('Fae')]),
    book('b', title: 'Le Prince Cruel', authors: ['Holly Black'], tags: [theme('Romantasy')]),
    book('c', title: 'Dracula', authors: ['Bram Stoker'], tags: [theme('Vampires')], status: ReadStatus.read, rating: 4),
  ];

  testWidgets('shows to-read books as a cover grid with count', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    expect(find.text('Ma pile'), findsOneWidget);
    expect(find.text('2 livres'), findsOneWidget);
    expect(find.byKey(const Key('cover-grid')), findsOneWidget);
    expect(find.text('Fourth Wing'), findsWidgets);
    expect(find.text('Dracula'), findsNothing);
  });

  testWidgets('floating navigation switches between pile, reading and read', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    for (final label in ['Pile', 'En cours', 'Lus', 'Synchro']) {
      expect(find.descendant(of: find.byKey(const Key('nav')), matching: find.text(label)), findsOneWidget);
    }
    await tester.tap(find.descendant(of: find.byKey(const Key('nav')), matching: find.text('En cours')));
    await tester.pump();
    expect(find.text('0 livre'), findsOneWidget);
  });

  testWidgets('tapping two chips keeps books having both', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.tap(find.widgetWithText(FilterChip, 'Romantasy'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Fae'));
    await tester.pump();
    expect(find.text('1 livre'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsWidgets);
    expect(find.text('Le Prince Cruel'), findsNothing);
  });

  testWidgets('search filters by author', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.enterText(find.byType(TextField), 'holly');
    await tester.pump();
    expect(find.text('Le Prince Cruel'), findsWidgets);
    expect(find.text('Fourth Wing'), findsNothing);
  });

  testWidgets('status Lus shows read books with stars', (tester) async {
    await tester.pumpWidget(app(await controllerWith(books)));
    await tester.tap(find.descendant(of: find.byKey(const Key('nav')), matching: find.text('Lus')));
    await tester.pump();
    expect(find.text('Mes lectures'), findsOneWidget);
    expect(find.text('Dracula'), findsWidgets);
    expect(find.text('★★★★'), findsOneWidget);
    expect(find.text('Fourth Wing'), findsNothing);
  });

  testWidgets('books with few tags show the à compléter badge', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(await controllerWith(books)));
    expect(find.bySemanticsLabel(RegExp('à compléter')), findsNWidgets(2));
    semantics.dispose();
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

  testWidgets('with pinned themes, the row shows only them, then Plus', (tester) async {
    final many = [
      for (var i = 0; i < 8; i++)
        book('x$i', title: 'Livre $i', tags: [for (var j = 0; j <= i; j++) theme('T$j')]),
    ];
    final pins = PinnedTags()..pinned = ['T7', 'T2'];
    await tester.pumpWidget(app(await controllerWith(many), pins: pins));
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).map((c) => (c.label as Text).data).toList();
    expect(chips, ['T7', 'T2']);
    expect(find.widgetWithText(ActionChip, 'Plus'), findsOneWidget);
  });

  testWidgets('without pinned themes, the row shows the 5 most frequent', (tester) async {
    final many = [
      for (var i = 0; i < 8; i++)
        book('x$i', title: 'Livre $i', tags: [for (var j = 0; j <= i; j++) theme('T$j')]),
    ];
    await tester.pumpWidget(app(await controllerWith(many)));
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).map((c) => (c.label as Text).data).toList();
    expect(chips, ['T0', 'T1', 'T2', 'T3', 'T4']);
  });

  testWidgets('a selected theme outside the 5 stays visible in the row', (tester) async {
    final many = [
      for (var i = 0; i < 8; i++)
        book('x$i', title: 'Livre $i', tags: [for (var j = 0; j <= i; j++) theme('T$j')]),
    ];
    await tester.pumpWidget(app(await controllerWith(many)));
    await tester.tap(find.widgetWithText(ActionChip, 'Plus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'T6');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'T6'));
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).map((c) => (c.label as Text).data).toList();
    expect(chips.first, 'T6');
    expect(chips.length, 6);
  });
}
