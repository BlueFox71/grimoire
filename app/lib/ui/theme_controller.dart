import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choix clair / sombre / système, mémorisé sur l'appareil.
class ThemeController extends ChangeNotifier {
  static const _key = 'themeMode';
  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = ThemeMode.values.asNameMap()[prefs.getString(_key)] ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }
}
