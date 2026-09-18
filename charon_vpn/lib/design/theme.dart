import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

class CharonTheme {
  CharonTheme._();

  static ThemeData dark() => _themeFor(
        brightness: Brightness.dark,
        background: const Color(0xFF0B0E14),
        surface: const Color(0xFF1F2937),
        foreground: const Color(0xFFE8EAED),
        muted: const Color(0xFF8A95A6),
        steel: const Color(0xFF374151),
        caution: const Color(0xFFF5B301),
      );

  static ThemeData light() => _themeFor(
        brightness: Brightness.light,
        background: const Color(0xFFECEFF4),
        surface: const Color(0xFFFFFFFF),
        foreground: const Color(0xFF131722),
        muted: const Color(0xFF5B6472),
        steel: const Color(0xFFB8C1D0),
        caution: const Color(0xFFB57D00),
      );

  static ThemeData _themeFor({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color muted,
    required Color steel,
    required Color caution,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: CharonFonts.body,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: CharonColors.primaryBright,
        onPrimary: Colors.white,
        secondary: caution,
        onSecondary: Colors.black,
        error: CharonColors.critical,
        onError: Colors.white,
        surface: surface,
        onSurface: foreground,
      ),
      dividerColor: steel,
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontFamily: CharonFonts.body, color: foreground),
        bodyMedium: TextStyle(fontFamily: CharonFonts.body, color: foreground),
        bodySmall: TextStyle(fontFamily: CharonFonts.body, color: muted),
      ),
    );
  }
}
