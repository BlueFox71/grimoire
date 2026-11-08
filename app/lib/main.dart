import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'core/library_controller.dart';
import 'core/library_store.dart';
import 'ui/home_screen.dart';
import 'ui/pinned_tags.dart';
import 'ui/theme.dart';
import 'ui/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // GRIMOIRE_DATA permet d'ouvrir une autre bibliothèque (aperçu, essais) sans toucher à la vraie.
  final override = Platform.environment['GRIMOIRE_DATA'];
  final dir = override != null && override.isNotEmpty ? Directory(override) : await getApplicationSupportDirectory();
  final library = LibraryController(LibraryStore(dir));
  final theme = ThemeController();
  final pins = PinnedTags();
  await Future.wait([library.load(), theme.load(), pins.load()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: pins),
      ],
      child: const GrimoireApp(),
    ),
  );
}

class GrimoireApp extends StatefulWidget {
  const GrimoireApp({super.key});

  @override
  State<GrimoireApp> createState() => _GrimoireAppState();
}

class _GrimoireAppState extends State<GrimoireApp> {
  // Enregistre tout de suite quand l'appli passe en arrière-plan ou se ferme
  // (sinon une modification de moins de 500 ms pourrait être perdue).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: _flush,
    onPause: _flush,
    onDetach: _flush,
    onExitRequested: () async {
      await _flush();
      return AppExitResponse.exit;
    },
  );

  Future<void> _flush() => context.read<LibraryController>().flush();

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
