import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/tags.dart';
import 'pinned_tags.dart';
import 'theme.dart';

/// Liste complète des étiquettes avec compteur, recherche et cases à cocher.
/// Renvoie le nouvel ensemble sélectionné (ou null si on revient sans appliquer).
class TagPicker extends StatefulWidget {
  final List<MapEntry<String, int>> counts;
  final Set<String> selected;
  const TagPicker({super.key, required this.counts, required this.selected});

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';
  String? _message;

  Future<void> _togglePin(PinnedTags pins, String name) async {
    final ok = await pins.toggle(name);
    if (mounted) {
      setState(() => _message = ok ? null : "${PinnedTags.maxPinned} thèmes épinglés au maximum : retire d'abord une étoile.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pins = context.watch<PinnedTags>();
    final gc = context.gc;
    final q = normalize(_query);
    final shown = widget.counts.where((e) => q.isEmpty || normalize(e.key).contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thèmes et tropes'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Appliquer')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Chercher un thème ou un trope…', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              _message ?? "Touche l'étoile pour épingler un thème en tête de ta pile (${PinnedTags.maxPinned} au maximum).",
              style: TextStyle(color: _message == null ? gc.muted : gc.title, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final e = shown[i];
                final isPinned = pins.isPinned(e.key);
                return CheckboxListTile(
                  value: _selected.contains(e.key),
                  title: Text(e.key),
                  subtitle: Text('${e.value} livre${e.value > 1 ? 's' : ''}', style: TextStyle(color: gc.muted, fontSize: 12)),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: IconButton(
                    key: Key('pin-${e.key}'),
                    tooltip: isPinned ? 'Désépingler' : 'Épingler',
                    icon: Icon(isPinned ? Icons.star : Icons.star_border, color: isPinned ? gc.title : gc.muted),
                    onPressed: () => _togglePin(pins, e.key),
                  ),
                  onChanged: (v) => setState(() => v == true ? _selected.add(e.key) : _selected.remove(e.key)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
