import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/library_controller.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/ui/book_screen.dart';
import 'package:grimoire/ui/theme.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

LibraryController controller() {
  final lib = Library()
    ..books['x'] = (book('x', title: 'Fourth Wing', tags: [theme('Dragons'), theme('Magie'), trope('Found family')])
      ..series = 'The Empyrean'
      ..volume = 1
      ..summary = 'Rien ne prédestinait Violet.');
  return LibraryController(MemoryStore(), initial: lib);
}

Widget app(LibraryController c) => ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: grimoireLight(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookScreen(bookId: 'x'))),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

Future<LibraryController> openBook(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = controller();
  await tester.pumpWidget(app(c));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('shows series, summary and tags', (tester) async {
    await openBook(tester);
    expect(find.text('The Empyrean, tome 1'), findsOneWidget);
    expect(find.text('Rien ne prédestinait Violet.'), findsOneWidget);
    expect(find.text('Found family'), findsOneWidget);
  });

  testWidgets('marking read sets status and readAt', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.text('Lu'));
    await tester.pump(const Duration(seconds: 1));
    final b = c.book('x')!;
    expect(b.status, ReadStatus.read);
    expect(b.readAt, isNotNull);
    expect(b.userEditedAt['status'], isNotNull);
  });

  testWidgets('je le lis sets reading', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.text('Je le lis'));
    await tester.pump(const Duration(seconds: 1));
    expect(c.book('x')!.status, ReadStatus.reading);
  });

  testWidgets('tapping 4th star sets rating 4, tapping it again clears', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pump(const Duration(seconds: 1));
    expect(c.book('x')!.rating, 4);
    expect(c.book('x')!.userEditedAt['rating'], isNotNull);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pump(const Duration(seconds: 1));
    expect(c.book('x')!.rating, 0);
  });

  testWidgets('comment is saved when leaving the field', (tester) async {
    final c = await openBook(tester);
    await tester.enterText(find.byKey(const Key('comment')), 'Coup de cœur');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));
    expect(c.book('x')!.comment, 'Coup de cœur');
    expect(c.book('x')!.userEditedAt['comment'], isNotNull);
  });

  testWidgets('removing a tag adds it to manualRemoved', (tester) async {
    final c = await openBook(tester);
    await tester.longPress(find.text('Magie'));
    await tester.pump(const Duration(seconds: 1));
    expect(c.book('x')!.manualRemoved, {'Magie'});
    expect(find.text('Magie'), findsNothing);
  });

  testWidgets('adding trope Fae adds trope:Fae', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.text('Ajouter une étiquette'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trope'));
    await tester.enterText(find.byKey(const Key('new-tag')), 'Fae');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(c.book('x')!.manualAdded, {'trope:Fae'});
    expect(find.text('Fae'), findsOneWidget);
  });

  testWidgets('retirer asks confirmation then deletes', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.text('Retirer de Grimoire'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Il ne reviendra pas au prochain import'), findsOneWidget);
    expect(c.book('x')!.deleted, isFalse);
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(c.book('x')!.deleted, isTrue);
    expect(find.text('ouvrir'), findsOneWidget);
  });
}
