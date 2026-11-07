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
    await tester.tap(find.text('Importer un export Booknode'));
    await tester.pumpAndSettle();
    expect(find.text('3 ajoutés · 0 mis à jour · 0 retirés · 0 différents de Booknode'), findsOneWidget);
    expect(c.library.visible.length, 3);
    expect(store.backups, ['avant-import']);
  });

  testWidgets('import of a wrong file shows a clear error', (tester) async {
    final c = LibraryController(MemoryStore(), initial: Library());
    await tester.pumpWidget(app(c, () async => '{"hello": 1}'));
    await tester.tap(find.text('Importer un export Booknode'));
    await tester.pumpAndSettle();
    expect(find.text("Ce fichier n'est pas un export Booknode de Grimoire."), findsOneWidget);
    expect(c.library.books, isEmpty);
  });

  testWidgets('cancelled file picker changes nothing', (tester) async {
    final store = MemoryStore();
    final c = LibraryController(store, initial: Library());
    await tester.pumpWidget(app(c, () async => null));
    await tester.tap(find.text('Importer un export Booknode'));
    await tester.pumpAndSettle();
    expect(store.backups, isEmpty);
  });
}
