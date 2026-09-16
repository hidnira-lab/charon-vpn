import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

class CharonTheme {
  CharonTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CharonColors.background,
      fontFamily: CharonFonts.body,
      colorScheme: const ColorScheme.dark(
        primary: CharonColors.primaryBright,
        secondary: CharonColors.caution,
        error: CharonColors.critical,
        surface: CharonColors.surface,
        onSurface: CharonColors.foreground,
      ),
      dividerColor: CharonColors.steel,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: CharonFonts.body, color: CharonColors.foreground),
        bodyMedium: TextStyle(fontFamily: CharonFonts.body, color: CharonColors.foreground),
        bodySmall: TextStyle(fontFamily: CharonFonts.body, color: CharonColors.muted),
      ),
    );
  }
}
