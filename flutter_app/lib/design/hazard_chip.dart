import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

enum HazardChipTone { caution, critical }

/// Small diagonal-stripe badge for inline severity labels ("Critical
/// safeguard", "Transition handler") — mirrors the `.hazard-stripe(-red)`
/// CSS classes used as chip backgrounds in the reference.
class HazardChip extends StatelessWidget {
  const HazardChip({super.key, required this.label, this.tone = HazardChipTone.caution});

  final String label;
  final HazardChipTone tone;

  @override
  Widget build(BuildContext context) {
    final stripeColor = tone == HazardChipTone.critical ? CharonColors.critical : CharonColors.caution;
    final textColor = tone == HazardChipTone.critical ? CharonColors.foreground : CharonColors.background;
    final outlineColor = tone == HazardChipTone.critical ? CharonColors.background : CharonColors.foreground;
    const baseStyle = TextStyle(
      fontFamily: CharonFonts.mono,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    );
    return ClipRect(
      child: CustomPaint(
        painter: _ChipStripePainter(stripeColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // Alternating diagonal stripes behind the label make plain fill
          // text illegible wherever a glyph lands on the same-tone stripe —
          // an outline keeps it readable regardless of what's underneath.
          child: Stack(
            children: [
              Text(
                label,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = outlineColor,
                ),
              ),
              Text(label, style: baseStyle.copyWith(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipStripePainter extends CustomPainter {
  _ChipStripePainter(this.color);

  final Color color;
  static const _stripeWidth = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141000));
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
  bool shouldRepaint(covariant _ChipStripePainter oldDelegate) => oldDelegate.color != color;
}
