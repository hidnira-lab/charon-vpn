import 'package:flutter/widgets.dart';

/// Color tokens from `needs/ui-ux-reference` ("mecha technical console").
/// Dark mode is the default; light mode ports the concrete palette already
/// defined in the reference's `index.css` (`:root.light`) rather than
/// inventing new values (Milestone 13).
class CharonColors {
  CharonColors._();

  /// Global light/dark switch. A `ValueNotifier` (not a per-widget `Theme`
  /// lookup) so every existing `CharonColors.xxx` call site below keeps
  /// working unchanged — only the `const` constructors that referenced the
  /// now-dynamic fields needed to drop `const`. See `CharonApp` in
  /// `main.dart` for the `ValueListenableBuilder` that rebuilds the
  /// `MaterialApp` theme when this flips.
  static final isLight = ValueNotifier<bool>(false);

  static Color get background => isLight.value ? _lightBackground : _darkBackground;
  static Color get surface => isLight.value ? _lightSurface : _darkSurface;
  static Color get surface2 => isLight.value ? _lightSurface2 : _darkSurface2;
  static Color get foreground => isLight.value ? _lightForeground : _darkForeground;
  static Color get muted => isLight.value ? _lightMuted : _darkMuted;
  static Color get steel => isLight.value ? _lightSteel : _darkSteel;
  static Color get caution => isLight.value ? _lightCaution : _darkCaution;

  // Semantic accents stay identical across themes — they carry meaning
  // (connected/critical/transition), not decoration, so they don't shift
  // with the light/dark ground tokens above.
  static const primary = Color(0xFF1D4ED8);
  static const primaryBright = Color(0xFF3B82F6);
  static const critical = Color(0xFFDC2626);

  static const _darkBackground = Color(0xFF0B0E14);
  static const _darkSurface = Color(0xFF1F2937);
  static const _darkSurface2 = Color(0xFF161D29);
  static const _darkForeground = Color(0xFFE8EAED);
  static const _darkMuted = Color(0xFF8A95A6);
  static const _darkSteel = Color(0xFF374151);
  static const _darkCaution = Color(0xFFF5B301);

  static const _lightBackground = Color(0xFFECEFF4);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurface2 = Color(0xFFDDE3EC);
  static const _lightForeground = Color(0xFF131722);
  static const _lightMuted = Color(0xFF5B6472);
  static const _lightSteel = Color(0xFFB8C1D0);
  static const _lightCaution = Color(0xFFB57D00);
}
