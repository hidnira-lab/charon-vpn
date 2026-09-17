import 'package:flutter/material.dart';

import 'colors.dart';
import 'fonts.dart';

enum ReadoutTone { normal, primary, caution }

/// HUD-style key/value pair with a left accent border — used for link
/// telemetry (egress IP, latency, throughput, etc).
class Readout extends StatelessWidget {
  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.tone = ReadoutTone.normal,
  });

  final String label;
  final String value;
  final String? unit;
  final ReadoutTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ReadoutTone.primary => CharonColors.primaryBright,
      ReadoutTone.caution => CharonColors.caution,
      ReadoutTone.normal => CharonColors.foreground,
    };
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: CharonColors.steel, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: CharonFonts.display,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: CharonColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 18, color: color)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 12, color: CharonColors.muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
