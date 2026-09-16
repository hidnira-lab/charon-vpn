import 'package:flutter/material.dart';

import 'clippers.dart';
import 'colors.dart';
import 'fonts.dart';

/// Beveled technical card with an optional unit code label in the corner —
/// the base card motif used across every screen in the redesign.
class UnitPlate extends StatelessWidget {
  const UnitPlate({
    super.key,
    this.code,
    this.active = false,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? code;
  final bool active;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? CharonColors.primaryBright : CharonColors.steel;
    return ClipPath(
      clipper: const UnitPlateClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: CharonColors.surface,
          border: Border.all(color: borderColor, width: active ? 1.5 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: CharonColors.primaryBright.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            if (code != null)
              Positioned(
                right: 12,
                top: 8,
                child: Text(
                  code!,
                  style: const TextStyle(
                    fontFamily: CharonFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: CharonColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
