import 'package:flutter/widgets.dart';

/// Beveled top-right corner clip, mirrors the `.unit-plate` clip-path from
/// the Figma Make reference (`clip-path: polygon(0 0, calc(100% - 14px) 0,
/// 100% 14px, 100% 100%, 0 100%)`).
class UnitPlateClipper extends CustomClipper<Path> {
  const UnitPlateClipper({this.cut = 14});

  final double cut;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final c = cut > w ? w : cut;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w - c, 0)
      ..lineTo(w, c)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant UnitPlateClipper oldClipper) => oldClipper.cut != cut;
}
