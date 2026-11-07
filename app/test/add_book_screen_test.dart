import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/google_books.dart';
import 'package:grimoire/core/library_controller.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/core/tags.dart';
import 'package:grimoire/ui/add_book_screen.dart';
import 'package:grimoire/ui/theme.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Widget app(LibraryController c, BookSearch search) => ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: grimoireLight(), home: AddBookScreen(search: search)),
    );

void main() {
  testWidgets('search result tap adds book as to-read and needing completion', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, (q) async {
      expect(q, 'prince cruel');
      return [BookCandidate(title: 'Le Prince cruel', authors: ['Holly Black'])];
    }));
    await tester.enterText(find.byKey(const Key('search')), 'prince cruel');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le Prince cruel'));
    await tester.pumpAndSettle();
    final b = c.library.visible.single;
    expect(b.title, 'Le Prince cruel');
    expect(b.status, ReadStatus.toRead);
    expect(needsCompletion(b), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search error offers manual add', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, (q) async => throw BookSearchException("Pas de connexion : tu peux l'ajouter à la main.")));
    await tester.enterText(find.byKey(const Key('search')), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text("Pas de connexion : tu peux l'ajouter à la main."), findsOneWidget);
  });

  testWidgets('manual add creates local book', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, (q) async => []));
    await tester.tap(find.text('Ajouter à la main'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('manual-title')), 'Mon livre');
    await tester.enterText(find.byKey(const Key('manual-author')), 'Une Autrice');
    await tester.tap(find.text('Créer la fiche'));
    await tester.pumpAndSettle();
    final b = c.library.visible.single;
    expect(b.id, startsWith('local:'));
    expect(b.title, 'Mon livre');
    expect(b.authors, ['Une Autrice']);
    await tester.pump(const Duration(seconds: 1));
  });
}
