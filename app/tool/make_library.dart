// Construit une bibliothèque Grimoire à partir d'un export Booknode, dans un dossier donné.
// Usage : dart run tool/make_library.dart <export.json> <dossier>
import 'dart:convert';
import 'dart:io';

import 'package:grimoire/core/booknode_import.dart';
import 'package:grimoire/core/library_store.dart';
import 'package:grimoire/core/model.dart';

Future<void> main(List<String> args) async {
  final export = jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  final store = LibraryStore(Directory(args[1]));
  final lib = await store.load();
  final r = applyExport(lib, export, DateTime.now().toUtc());
  await store.save(lib);
  stdout.writeln('${r.added.length} ajoutés · ${r.updated.length} mis à jour · ${r.removed.length} retirés · '
      '${r.differs.length} différents · ${lib.visible.where((b) => b.status == ReadStatus.toRead).length} à lire');
}
