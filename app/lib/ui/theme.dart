import 'package:flutter/material.dart';

/// Couleurs propres à Grimoire, accessibles via `Theme.of(context).extension<GrimoireColors>()`.
@immutable
class GrimoireColors extends ThemeExtension<GrimoireColors> {
  final Color surface;
  final Color muted;
  final Color title;
  final Color accent;
  final Color onAccent;

  const GrimoireColors({
    required this.surface,
    required this.muted,
    required this.title,
    required this.accent,
    required this.onAccent,
  });

  @override
  GrimoireColors copyWith({Color? surface, Color? muted, Color? title, Color? accent, Color? onAccent}) =>
      GrimoireColors(
        surface: surface ?? this.surface,
        muted: muted ?? this.muted,
        title: title ?? this.title,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
      );

  @override
  GrimoireColors lerp(GrimoireColors? other, double t) => other == null
      ? this
      : GrimoireColors(
          surface: Color.lerp(surface, other.surface, t)!,
          muted: Color.lerp(muted, other.muted, t)!,
          title: Color.lerp(title, other.title, t)!,
          accent: Color.lerp(accent, other.accent, t)!,
          onAccent: Color.lerp(onAccent, other.onAccent, t)!,
        );
}

extension GrimoireTheme on BuildContext {
  GrimoireColors get gc => Theme.of(this).extension<GrimoireColors>()!;
}

const displayFont = 'Cormorant Garamond';
const bodyFont = 'Nunito Sans';

/// Style de titre (police à graisse variable : on fixe l'axe `wght`).
TextStyle displayStyle(double size, Color color, {int weight = 700}) => TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: 1.15,
    );

ThemeData _build({
  required Brightness brightness,
  required Color bg,
  required Color surface,
  required Color text,
  required Color muted,
  required Color accent,
  required Color title,
  required Color onAccent,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: accent,
    onPrimary: onAccent,
    surface: bg,
    onSurface: text,
    surfaceContainerHighest: surface,
    secondaryContainer: accent,
    onSecondaryContainer: onAccent,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: bodyFont,
  );
  return base.copyWith(
    extensions: [GrimoireColors(surface: surface, muted: muted, title: title, accent: accent, onAccent: onAccent)],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: displayStyle(26, title),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: displayStyle(28, title),
      titleLarge: displayStyle(22, title),
      titleMedium: displayStyle(18, text, weight: 600),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accent,
      labelStyle: TextStyle(fontFamily: bodyFont, color: text, fontSize: 13),
      secondaryLabelStyle: TextStyle(fontFamily: bodyFont, color: onAccent, fontSize: 13),
      checkmarkColor: onAccent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    dividerColor: surface,
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: accent, foregroundColor: onAccent),
  );
}

/// Mode sombre « Grimoire nocturne ».
ThemeData grimoireDark() => _build(
      brightness: Brightness.dark,
      bg: const Color(0xFF1B1626),
      surface: const Color(0xFF2E2640),
      text: const Color(0xFFECE6F7),
      muted: const Color(0xFFA99CC4),
      accent: const Color(0xFF8A5CF6),
      title: const Color(0xFFE8C77A),
      onAccent: Colors.white,
    );

/// Mode clair « Aube rosée ».
ThemeData grimoireLight() => _build(
      brightness: Brightness.light,
      bg: const Color(0xFFFBF4F6),
      surface: const Color(0xFFF0E1E8),
      text: const Color(0xFF3B2733),
      muted: const Color(0xFF8A6D7C),
      accent: const Color(0xFFA8456F),
      title: const Color(0xFFA8456F),
      onAccent: Colors.white,
    );
