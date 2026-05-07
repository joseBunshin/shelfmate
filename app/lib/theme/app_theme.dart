// Design tokens, color, typography. Material 3 with brand-tuned seed.
//
// Final palette + share-card-specific tokens land in U4 alongside the
// finish-book celebration design specs.

import 'package:flutter/material.dart';

/// Brand seed color. Subject to change as final design lands.
const Color shelfMateSeed = Color(0xFF1F2937); // zinc-800-ish — quiet, neutral.

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: shelfMateSeed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: shelfMateSeed,
    brightness: Brightness.dark,
  );
  return buildLightTheme().copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
  );
}
