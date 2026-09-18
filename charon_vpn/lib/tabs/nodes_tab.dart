import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';
import '../server_profiles.dart';

/// Unit-plate grid replacing the old `ProfilesPage`. Ping/load fields from
/// the Figma Make reference are dropped — there's no mechanism to measure
/// them yet (Milestone 6.2 is UI-only, per Dayat's placeholder-first call).
class NodesTab extends StatelessWidget {
  const NodesTab({
    super.key,
    required this.profiles,
    required this.activeId,
    required this.locked,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onImportLink,
  });

  final List<ServerProfile> profiles;
  final String? activeId;
  final bool locked;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ServerProfile> onEdit;
  final ValueChanged<ServerProfile> onDelete;
  final VoidCallback onImportLink;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            index: '02',
            title: 'Server Nodes',
            desc: 'Registered exit nodes. Select a unit to route the tunnel.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Import dari vless:// link',
                  onPressed: onImportLink,
                  icon: Icon(LucideIcons.link, color: CharonColors.muted),
                ),
                IconButton(
                  tooltip: 'Tambah profile',
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, color: CharonColors.primaryBright),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (profiles.isEmpty)
            UnitPlate(
              child: Text(
                'Belum ada server profile. Tambah lewat tombol + di atas.',
                style: TextStyle(color: CharonColors.muted),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < profiles.length; i++)
                  SizedBox(
                    width: 300,
                    child: _NodeCard(
                      code: 'SRV-${(i + 1).toString().padLeft(2, '0')}',
                      profile: profiles[i],
                      active: profiles[i].id == activeId,
                      onTap: () => onSelect(profiles[i].id),
                      onEdit: () => onEdit(profiles[i]),
                      onDelete: () => onDelete(profiles[i]),
                    ),
                  ),
              ],
            ),
          if (locked) ...[
            const SizedBox(height: 24),
            Text(
              'Disconnect dulu buat ganti atau hapus profile yang lagi aktif.',
              style: TextStyle(color: CharonColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.code,
    required this.profile,
    required this.active,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String code;
  final ServerProfile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: UnitPlate(
          code: code,
          active: active,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: CharonColors.surface2, border: Border.all(color: CharonColors.steel)),
                    child: const Icon(LucideIcons.server, color: CharonColors.primaryBright),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: techLabel(fontSize: 15), overflow: TextOverflow.ellipsis),
                        Text(
                          profile.serverIp,
                          style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: CharonColors.primaryBright),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: Icon(LucideIcons.pencil, size: 16, color: CharonColors.muted),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    icon: Icon(LucideIcons.trash2, size: 16, color: CharonColors.muted),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
