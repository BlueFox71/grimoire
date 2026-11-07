import 'package:flutter/material.dart';

import '../core/tags.dart';

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

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final e = shown[i];
                return CheckboxListTile(
                  value: _selected.contains(e.key),
                  title: Text(e.key),
                  secondary: Text('${e.value}'),
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
