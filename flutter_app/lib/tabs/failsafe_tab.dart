import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

/// Restyled per Milestone 6.3 — full "mecha console" treatment
/// (`UnitPlate` + `RockerToggle` + `HazardChip`) instead of the plain
/// `SwitchListTile` placeholder from Milestone 6.1.
class FailsafeTab extends StatelessWidget {
  const FailsafeTab({
    super.key,
    required this.killSwitch,
    required this.onKillSwitchChanged,
    required this.autoReconnect,
    required this.onAutoReconnectChanged,
  });

  final bool killSwitch;
  final ValueChanged<bool> onKillSwitchChanged;
  final bool autoReconnect;
  final ValueChanged<bool> onAutoReconnectChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            index: '04',
            title: 'Reliability',
            desc: 'Fail-safe behavior when the link degrades or drops.',
          ),
          const SizedBox(height: 24),
          UnitPlate(
            code: 'RLB-KS',
            child: _ReliabilityRow(
              icon: LucideIcons.shield,
              iconColor: CharonColors.critical,
              title: 'Kill Switch',
              // Deliberately more precise than the reference copy ("Block
              // all network egress if the tunnel fails") - see the
              // Dashboard hazard-banner comment for why overclaiming here
              // would be a false safety guarantee.
              desc: "Blocks new connections if xray crashes unexpectedly while connected — the TUN "
                  "adapter stays up until it reconnects. Doesn't apply to a manual disconnect or if "
                  "the TUN adapter itself is lost.",
              chip: const HazardChip(label: 'CRITICAL SAFEGUARD', tone: HazardChipTone.critical),
              toggle: RockerToggle(
                value: killSwitch,
                onChanged: onKillSwitchChanged,
                tone: RockerTone.critical,
                labelOn: 'ARM',
                labelOff: 'OFF',
              ),
            ),
          ),
          const SizedBox(height: 16),
          UnitPlate(
            code: 'RLB-AR',
            child: _ReliabilityRow(
              icon: LucideIcons.activity,
              iconColor: CharonColors.caution,
              title: 'Auto-Reconnect',
              desc: 'Automatically restarts xray and the tunnel after a drop. Retries 5 times, '
                  '5 seconds apart, per profile — if there\'s more than one saved profile, it fails '
                  'over through the rest before giving up.',
              chip: const HazardChip(label: 'TRANSITION HANDLER', tone: HazardChipTone.caution),
              toggle: RockerToggle(value: autoReconnect, onChanged: onAutoReconnectChanged, tone: RockerTone.caution),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityRow extends StatelessWidget {
  const _ReliabilityRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
    required this.chip,
    required this.toggle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;
  final Widget chip;
  final Widget toggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                  Text(title, style: techLabel(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 13, color: CharonColors.muted, height: 1.4)),
              const SizedBox(height: 12),
              chip,
            ],
          ),
        ),
        const SizedBox(width: 24),
        toggle,
      ],
    );
  }
}
