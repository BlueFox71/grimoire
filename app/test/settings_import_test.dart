import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire/core/library_controller.dart';
import 'package:grimoire/core/model.dart';
import 'package:grimoire/ui/settings_screen.dart';
import 'package:grimoire/ui/theme.dart';
import 'package:grimoire/ui/theme_controller.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Widget app(LibraryController c, Future<String?> Function() pick) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: c),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(theme: grimoireLight(), home: SettingsScreen(showImport: true, pickFile: pick)),
    );

void main() {
  final exportJson = File('test/fixtures/export_small.json').readAsStringSync();

  testWidgets('import shows summary counts and backs up first', (tester) async {
    final store = MemoryStore();
    final c = LibraryController(store, initial: Library());
    await tester.pumpWidget(app(c, () async => exportJson));
    await tester.tap(find.text("Choisir le fichier d'export…"));
    await tester.pumpAndSettle();
    expect(find.text('3 ajoutés · 0 mis à jour · 0 retirés · 0 différents de Booknode'), findsOneWidget);
    expect(c.library.visible.length, 3);
    expect(store.backups, ['avant-import']);
  });

  testWidgets('import of a wrong file shows a clear error', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, () async => '{"hello": 1}'));
    await tester.tap(find.text("Choisir le fichier d'export…"));
    await tester.pumpAndSettle();
    expect(find.text("Ce fichier n'est pas un export Booknode de Grimoire."), findsOneWidget);
    expect(c.library.books, isEmpty);
  });

  testWidgets('cancelled file picker changes nothing', (tester) async {
    final store = MemoryStore();
    final c = LibraryController(store, initial: Library());
    await tester.pumpWidget(app(c, () async => null));
    await tester.tap(find.text("Choisir le fichier d'export…"));
    await tester.pumpAndSettle();
    expect(store.backups, isEmpty);
  });

  testWidgets('booknode section explains the steps and shows the last import', (tester) async {
    final lib = Library()..lastImportAt = DateTime.utc(2026, 11, 8, 1, 40);
    lib.books['a'] = book('a');
    lib.books['b'] = book('b', status: ReadStatus.read);
    final c = LibraryController(MemoryStore(), initial: lib);
    await tester.pumpWidget(app(c, () async => null));
    expect(find.text('Ma bibliothèque Booknode'), findsOneWidget);
    expect(find.text('Dernier import : 8 novembre 2026 · 1 à lire, 1 lu'), findsOneWidget);
    expect(find.textContaining('fais un export de ma bibliothèque Booknode'), findsOneWidget);
  });

  testWidgets('without any import the section says so', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, () async => null));
    expect(find.text("Aucun import pour l'instant"), findsOneWidget);
  });
}
