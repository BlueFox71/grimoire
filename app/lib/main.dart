import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/library_controller.dart';
import 'core/library_store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final library = LibraryController(LibraryStore(dir));
  final theme = ThemeController();
  await Future.wait([library.load(), theme.load()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: theme),
      ],
      child: const GrimoireApp(),
    ),
  );
}

class GrimoireApp extends StatelessWidget {
  const GrimoireApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Grimoire',
        debugShowCheckedModeBanner: false,
        theme: grimoireLight(),
        darkTheme: grimoireDark(),
        themeMode: context.watch<ThemeController>().mode,
        home: const HomeScreen(),
      );
}
