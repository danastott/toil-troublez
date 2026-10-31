import 'package:flutter/material.dart';

import '../game/cards.dart';

/// Palette and fonts for the whole app, drawn from the official rulebook:
/// gilded ink on parchment, deep teal, a moonlit Enchanted Forest.
class TNTTheme {
  TNTTheme._();

  // Core palette.
  static const Color deepTeal = Color(0xFF1F4E4A);
  static const Color deepTealDark = Color(0xFF143835);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldSoft = Color(0xFFE4C766);
  static const Color parchment = Color(0xFFEFE3C6);
  static const Color parchmentDark = Color(0xFFD9C69B);
  static const Color ink = Color(0xFF2A2118);
  static const Color moonlight = Color(0xFF8FB8C9);
  static const Color moss = Color(0xFF5C7A3F);
  static const Color ember = Color(0xFFB4572E);

  /// The card-face colors, sampled from the printed deck: Sun cards are
  /// rose-red, Moon cards are deep teal, and Star cards are woodland green.
  /// Each face is painted as a three-stop gradient so the art glows out of
  /// the color rather than sitting flat on it.
  static const Map<CardColor, Color> cardTint = {
    CardColor.sun: Color(0xFFD2545F), // rose-red
    CardColor.moon: Color(0xFF2F8FA3), // deep teal
    CardColor.star: Color(0xFF79A93F), // woodland green
  };

  static const Map<CardColor, Color> cardTintLight = {
    CardColor.sun: Color(0xFFF0795F),
    CardColor.moon: Color(0xFF57C7D4),
    CardColor.star: Color(0xFFB9D95A),
  };

  static const Map<CardColor, Color> cardTintDeep = {
    CardColor.sun: Color(0xFF7E2039),
    CardColor.moon: Color(0xFF0F3F58),
    CardColor.star: Color(0xFF2F5522),
  };

  /// Warm light used for the halo behind the card's subject.
  static const Map<CardColor, Color> cardGlow = {
    CardColor.sun: Color(0xFFFFC08A),
    CardColor.moon: Color(0xFFA7F0F0),
    CardColor.star: Color(0xFFE8F08A),
  };

  /// Saturated accent used for small painted details (sparkles, rims).
  static const Map<CardColor, Color> cardAccent = {
    CardColor.sun: Color(0xFFFFD27A),
    CardColor.moon: Color(0xFFC9F7F5),
    CardColor.star: Color(0xFFF1F5A8),
  };

  /// Warm cream for painted highlights and the moonlit card back.
  static const Color cardArt = Color(0xFFF8EFDA);

  /// Texture assets (already bundled, see pubspec.yaml).
  static const String textureParchment = 'assets/textures/parchment.jpg';
  static const String textureForest = 'assets/textures/forest.png';
  static const String textureWood = 'assets/textures/wood.jpg';

  // Fonts (already declared in pubspec.yaml).
  static const String fontDisplay = 'Rye';
  static const String fontTitle = 'Cinzel Decorative';
  static const String fontSerif = 'Fraunces';
  static const String fontUi = 'Nunito Sans';
  /// Geometric sans for card numbers: 3 and 5 stay clearly distinct.
  static const String fontNumber = 'Outfit';

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: deepTeal,
      primary: gold,
      secondary: moonlight,
      surface: parchment,
      onSurface: ink,
    ).copyWith(surfaceContainerHighest: parchmentDark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: deepTealDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepTeal,
        foregroundColor: goldSoft,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontTitle,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: goldSoft,
          letterSpacing: 1.2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 44,
          color: goldSoft,
        ),
        displayMedium: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 34,
          color: goldSoft,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontSerif,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: fontSerif,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(fontFamily: fontUi, fontSize: 16),
        bodyMedium: TextStyle(fontFamily: fontUi, fontSize: 14),
        bodySmall: TextStyle(fontFamily: fontUi, fontSize: 12),
      ),
      cardTheme: const CardThemeData(elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          elevation: 2,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontTitle,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldSoft,
          side: const BorderSide(color: gold, width: 1.2),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: fontTitle,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: gold, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: gold, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: goldSoft, width: 2),
        ),
        hintStyle: const TextStyle(fontFamily: fontUi, color: Colors.white54),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(fontFamily: fontUi, color: parchment),
      ),
    );
  }
}
