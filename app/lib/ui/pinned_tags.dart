import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thèmes épinglés (5 au maximum) : affichés en premier dans la rangée de pastilles.
/// Propres à chaque appareil (comme le thème clair/sombre), non synchronisés.
class PinnedTags extends ChangeNotifier {
  static const maxPinned = 5;
  static const _key = 'pinnedTags';

  List<String> pinned = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    pinned = prefs.getStringList(_key) ?? [];
    notifyListeners();
  }

  bool isPinned(String name) => pinned.contains(name);

  /// Épingle ou désépingle. Renvoie false si l'épingle est refusée (déjà 5).
  Future<bool> toggle(String name) async {
    if (pinned.contains(name)) {
      pinned = [...pinned]..remove(name);
    } else {
      if (pinned.length >= maxPinned) return false;
      pinned = [...pinned, name];
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, pinned);
    return true;
  }
}
