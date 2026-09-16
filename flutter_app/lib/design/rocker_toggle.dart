import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

enum RockerTone { primary, critical, caution }

/// Chunky physical-feeling toggle (not iOS-style) for consequential switches
/// like Kill Switch and Auto-Reconnect — mirrors `RockerToggle` in the
/// Figma Make reference.
class RockerToggle extends StatelessWidget {
  const RockerToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.tone = RockerTone.primary,
    this.labelOn = 'ON',
    this.labelOff = 'OFF',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final RockerTone tone;
  final String labelOn;
  final String labelOff;

  static const _width = 76.0;
  static const _height = 36.0;
  static const _thumbWidth = 34.0;

  Color get _toneColor => switch (tone) {
        RockerTone.critical => CharonColors.critical,
        RockerTone.caution => CharonColors.caution,
        RockerTone.primary => CharonColors.primaryBright,
      };

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: CharonColors.surface2,
            border: Border.all(color: value ? toneColor : CharonColors.steel),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: value ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    value ? labelOn : labelOff,
                    style: TextStyle(
                      fontFamily: CharonFonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: value ? toneColor : CharonColors.muted,
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: ClipPath(
                  clipper: const _ThumbClipper(),
                  child: Container(
                    width: _thumbWidth,
                    height: _height - 4,
                    decoration: BoxDecoration(
                      color: value ? toneColor : CharonColors.steel,
                      boxShadow: value
                          ? [
                              BoxShadow(
                                color: toneColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slanted right edge on the thumb (`clip-path: polygon(0 0, 100% 0, 85%
/// 100%, 0 100%)`), giving the toggle its "physical lever" look.
class _ThumbClipper extends CustomClipper<Path> {
  const _ThumbClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.85, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
