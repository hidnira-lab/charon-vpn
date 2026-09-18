import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

/// Stencil-style screen header: "UNIT.NN" eyebrow, title, optional
/// description and trailing action — used at the top of every screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.index, required this.title, this.desc, this.trailing});

  final String index;
  final String title;
  final String? desc;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: CharonColors.primaryBright),
                  const SizedBox(width: 8),
                  Text(
                    'UNIT.$index',
                    style: const TextStyle(
                      fontFamily: CharonFonts.mono,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: CharonColors.primaryBright,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(title, style: techLabel(fontSize: 26)),
              if (desc != null) ...[
                const SizedBox(height: 4),
                Text(
                  desc!,
                  style: TextStyle(fontFamily: CharonFonts.body, fontSize: 13, color: CharonColors.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
