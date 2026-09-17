import 'package:flutter/material.dart';

import 'clippers.dart';
import 'colors.dart';
import 'fonts.dart';

enum HazardTone { caution, critical }

/// Alert strip with a diagonal hazard stripe accent — used for kill-switch
/// and split-tunnel warnings. Mirrors `HazardBanner` in the reference.
class HazardBanner extends StatelessWidget {
  const HazardBanner({super.key, this.tone = HazardTone.caution, required this.child});

  final HazardTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final stripeColor = tone == HazardTone.critical ? CharonColors.critical : CharonColors.caution;
    return ClipPath(
      clipper: const UnitPlateClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(color: CharonColors.surface2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 12,
                child: ClipRect(child: CustomPaint(painter: _HazardStripePainter(stripeColor))),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: CharonFonts.mono,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: stripeColor,
                    ),
                    child: child,
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

class _HazardStripePainter extends CustomPainter {
  _HazardStripePainter(this.color);

  final Color color;
  static const _stripeWidth = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.15));
    final stripe = Paint()..color = color.withValues(alpha: 0.95);
    final diagonal = size.width + size.height;
    var x = -size.height;
    while (x < diagonal) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + _stripeWidth, 0)
        ..lineTo(x + _stripeWidth, size.height)
        ..close();
      canvas.drawPath(path, stripe);
      x += _stripeWidth * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) => oldDelegate.color != color;
}
