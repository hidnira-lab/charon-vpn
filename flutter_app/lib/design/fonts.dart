import 'package:flutter/widgets.dart';
import 'colors.dart';

class CharonFonts {
  CharonFonts._();

  static const display = 'Rajdhani';
  static const body = 'Inter';
  static const mono = 'JetBrains Mono';
}

/// Wide-tracking label style used for headings, nav items, and plate
/// captions — mirrors the `.tech-label` class in the reference CSS. Flutter
/// has no CSS `text-transform`, so callers must pass already-uppercased text.
TextStyle techLabel({
  double fontSize = 14,
  Color color = CharonColors.foreground,
  FontWeight weight = FontWeight.w600,
}) {
  return TextStyle(
    fontFamily: CharonFonts.display,
    fontWeight: weight,
    fontSize: fontSize,
    letterSpacing: fontSize * 0.12,
    color: color,
  );
}
