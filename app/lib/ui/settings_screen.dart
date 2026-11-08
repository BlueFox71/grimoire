import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/booknode_import.dart';
import '../core/library_controller.dart';
import '../core/model.dart';
import 'theme.dart';
import 'theme_controller.dart';

/// Ouvre le sélecteur de fichier et renvoie le contenu du fichier choisi (ou null).
Future<String?> pickJsonFile() async {
  final f = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'Export Booknode', extensions: ['json'])]);
  return f == null ? null : utf8.decode(await f.readAsBytes());
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _lastImportText(Library lib) {
  final d = lib.lastImportAt?.toLocal();
  if (d == null) return "Aucun import pour l'instant";
  final toRead = lib.visible.where((b) => b.status == ReadStatus.toRead).length;
  final read = lib.visible.where((b) => b.status == ReadStatus.read).length;
  return 'Dernier import : ${d.day} ${_months[d.month - 1]} ${d.year} · $toRead à lire, $read lu${read > 1 ? 's' : ''}';
}

class SettingsScreen extends StatefulWidget {
  final bool? showImport;
  final Future<String?> Function()? pickFile;
  const SettingsScreen({super.key, this.showImport, this.pickFile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ImportReport? _report;
  String? _error;
  bool _busy = false;

  Future<void> _import() async {
    final text = await (widget.pickFile ?? pickJsonFile)();
    if (text == null || !mounted) return;
    final controller = context.read<LibraryController>();
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
    });
    try {
      final export = jsonDecode(text);
      if (export is! Map<String, dynamic>) throw const FormatException();
      final lib = controller.library.copy();
      final report = applyExport(lib, export, DateTime.now().toUtc());
      await controller.store.backup('avant-import');
      await controller.replace(lib);
      if (mounted) setState(() => _report = report);
    } on FormatException {
      if (mounted) setState(() => _error = "Ce fichier n'est pas un export Booknode de Grimoire.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final gc = context.gc;
    final showImport = widget.showImport ?? Platform.isWindows;
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Apparence', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Système')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
                ],
                selected: {theme.mode},
                onSelectionChanged: (s) => theme.set(s.first),
              ),
              if (showImport) ...[
                const SizedBox(height: 28),
                Text('Ma bibliothèque Booknode', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_lastImportText(context.watch<LibraryController>().library), style: TextStyle(color: gc.title, fontSize: 13)),
                const SizedBox(height: 10),
                Text(
                  "1. Demande à Claude : « fais un export de ma bibliothèque Booknode ». Il crée un fichier "
                  "booknode-export-….json dans tes Téléchargements.\n"
                  "2. Choisis ce fichier ici : Grimoire ajoute tes nouveaux livres et met à jour les autres, "
                  "sans toucher à tes notes ni à tes avis.",
                  style: TextStyle(color: gc.muted, height: 1.5),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text("Choisir le fichier d'export…"),
                  ),
                ),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
                if (r != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${r.added.length} ajoutés · ${r.updated.length} mis à jour · ${r.removed.length} retirés · ${r.differs.length} différents de Booknode',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final (label, list) in [
                    ('Ajoutés', r.added),
                    ('Mis à jour', r.updated),
                    ('Retirés', r.removed),
                    ('Différents de Booknode (Grimoire garde ta version)', r.differs),
                  ])
                    if (list.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('$label (${list.length})'),
                        children: [for (final t in list) ListTile(dense: true, title: Text(t))],
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
