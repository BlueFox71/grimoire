import 'dart:convert';
import 'dart:io';

import 'model.dart';

/// Lecture/écriture de la bibliothèque dans `grimoire.json`, de façon sûre :
/// écriture dans un fichier temporaire puis renommage, copie `.bak` de la
/// version précédente, sauvegardes datées dans `backups/`.
class LibraryStore {
  static const keptBackups = 20;

  final Directory dir;
  LibraryStore(this.dir);

  File get _main => File('${dir.path}${Platform.pathSeparator}grimoire.json');
  File get _bak => File('${_main.path}.bak');
  File get _tmp => File('${_main.path}.tmp');
  Directory get _backups => Directory('${dir.path}${Platform.pathSeparator}backups');

  Future<Library> load() async {
    if (!await _main.exists()) {
      final fromBak = await _tryRead(_bak);
      return fromBak ?? Library();
    }
    final main = await _tryRead(_main);
    if (main != null) return main;
    final fromBak = await _tryRead(_bak);
    if (fromBak != null) return fromBak;
    await _main.rename('${_main.path}.corrompu-${_stamp(DateTime.now())}');
    return Library();
  }

  Future<Library?> _tryRead(File f) async {
    try {
      if (!await f.exists()) return null;
      return Library.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Library lib) async {
    await dir.create(recursive: true);
    await _tmp.writeAsString(jsonEncode(lib.toJson()), flush: true);
    if (await _main.exists()) {
      // On ne garde en .bak qu'une version lisible.
      if (await _tryRead(_main) != null) await _main.copy(_bak.path);
    }
    await _tmp.rename(_main.path);
  }

  Future<File> backup(String reason) async {
    await _backups.create(recursive: true);
    final base = '${_backups.path}${Platform.pathSeparator}grimoire-${_stamp(DateTime.now())}-$reason';
    var target = File('$base.json');
    for (var n = 2; await target.exists(); n++) {
      target = File('$base-$n.json');
    }
    if (await _main.exists()) {
      await _main.copy(target.path);
    } else {
      await target.writeAsString(jsonEncode(Library().toJson()));
    }
    final files = _backups.listSync().whereType<File>().toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    while (files.length > keptBackups) {
      await files.removeAt(0).delete();
    }
    return target;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';
}
