import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

/// Milestone 6.7 — UI only. Only "this device" is shown (derived from
/// `Platform`, not invented) since there's no pairing/sync mechanism yet
/// (Milestone 11 backend). No fake paired devices — that would misrepresent
/// a security-relevant feature (device pairing) as already working.
class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final osLabel = '${Platform.operatingSystem[0].toUpperCase()}${Platform.operatingSystem.substring(1)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            index: '06',
            title: 'Registered Units',
            desc: 'Paired devices sharing this Charon configuration.',
          ),
          const SizedBox(height: 24),
          UnitPlate(
            code: 'DEV-01',
            active: true,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: CharonColors.surface2, border: Border.all(color: CharonColors.steel)),
                  child: Icon(
                    isMobile ? LucideIcons.smartphone : LucideIcons.laptop,
                    color: CharonColors.primaryBright,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('This device', style: techLabel(fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: CharonColors.primaryBright)),
                            child: const Text(
                              'THIS UNIT',
                              style: TextStyle(
                                fontFamily: CharonFonts.mono,
                                fontSize: 9,
                                color: CharonColors.primaryBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        osLabel,
                        style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all(color: CharonColors.steel)),
            child: const Text(
              'Belum ada device lain yang ke-pair — sync konfigurasi lintas device (Milestone 11) '
              'belum dibangun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CharonColors.muted, fontSize: 12, fontFamily: CharonFonts.mono),
            ),
          ),
        ],
      ),
    );
  }
}
