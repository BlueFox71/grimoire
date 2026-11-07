import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'core/library_controller.dart';
import 'core/library_store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'ui/theme_controller.dart';

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
