import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

class SplitRule {
  const SplitRule({required this.name, required this.id, required this.excluded});

  final String name;
  final String id;
  final bool excluded;

  SplitRule copyWith({bool? excluded}) => SplitRule(name: name, id: id, excluded: excluded ?? this.excluded);
}

/// Milestone 6.5 — UI only. Rules live in local widget state (nothing is
/// persisted or actually excluded from the tunnel) until Milestone 7 builds
/// the real bypass mechanism (app-based on Android, domain/CIDR-based on
/// Windows — app-based Windows exclude is parked, needs WFP).
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
  final _apps = <SplitRule>[];
  final _domains = <SplitRule>[];

  Future<void> _openAddDialog({
    required String title,
    required String nameLabel,
    required String idLabel,
    required String idHint,
    required ValueChanged<SplitRule> onSubmit,
  }) async {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final result = await showDialog<SplitRule>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: nameLabel)),
              const SizedBox(height: 12),
              TextField(controller: idController, decoration: InputDecoration(labelText: idLabel, hintText: idHint)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || idController.text.trim().isEmpty) return;
              Navigator.of(context).pop(
                SplitRule(name: nameController.text.trim(), id: idController.text.trim(), excluded: true),
              );
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (result != null) onSubmit(result);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            index: '03',
            title: 'Split Tunneling',
            desc: 'Excluded targets bypass the tunnel. Handle with care.',
          ),
          const SizedBox(height: 16),
          const HazardBanner(
            tone: HazardTone.caution,
            child: Text('EXCLUDED TRAFFIC EGRESSES ON THE LOCAL NETWORK — UNPROTECTED'),
          ),
          const SizedBox(height: 8),
          const Text(
            'UI placeholder — rules di sini belum beneran ngecualiin apa-apa dari tunnel sampai '
            'Milestone 7 (backend exclude) digarap.',
            style: TextStyle(color: CharonColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final apps = _RuleList(
                heading: 'Applications',
                icon: LucideIcons.laptop,
                codePrefix: 'APP',
                items: _apps,
                emptyHint: 'applications',
                onAdd: () => _openAddDialog(
                  title: 'Exclude Application',
                  nameLabel: 'Nama app',
                  idLabel: 'Package/process name',
                  idHint: 'mis. com.tencent.mm (Android) atau steam.exe (Windows)',
                  onSubmit: (r) => setState(() => _apps.add(r)),
                ),
                onToggle: (i) => setState(() => _apps[i] = _apps[i].copyWith(excluded: !_apps[i].excluded)),
                onRemove: (i) => setState(() => _apps.removeAt(i)),
              );
              final domains = _RuleList(
                heading: 'Domains',
                icon: LucideIcons.globe,
                codePrefix: 'DNS',
                items: _domains,
                emptyHint: 'domains',
                onAdd: () => _openAddDialog(
                  title: 'Exclude Domain',
                  nameLabel: 'Domain',
                  idLabel: 'Match type',
                  idHint: 'mis. dns',
                  onSubmit: (r) => setState(() => _domains.add(r)),
                ),
                onToggle: (i) =>
                    setState(() => _domains[i] = _domains[i].copyWith(excluded: !_domains[i].excluded)),
                onRemove: (i) => setState(() => _domains.removeAt(i)),
              );
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: apps), const SizedBox(width: 24), Expanded(child: domains)],
                );
              }
              return Column(children: [apps, const SizedBox(height: 24), domains]);
            },
          ),
        ],
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({
    required this.heading,
    required this.icon,
    required this.codePrefix,
    required this.items,
    required this.emptyHint,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
  });

  final String heading;
  final IconData icon;
  final String codePrefix;
  final List<SplitRule> items;
  final String emptyHint;
  final VoidCallback onAdd;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: CharonColors.primaryBright),
                const SizedBox(width: 8),
                Text(heading.toUpperCase(), style: techLabel(fontSize: 13, color: CharonColors.muted)),
              ],
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16, color: CharonColors.primaryBright),
              label: const Text('Add', style: TextStyle(color: CharonColors.primaryBright)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all(color: CharonColors.steel)),
            child: Text(
              'No exclusions — all $emptyHint routed through tunnel',
              textAlign: TextAlign.center,
              style: const TextStyle(color: CharonColors.muted, fontSize: 12, fontFamily: CharonFonts.mono),
            ),
          )
        else
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
              child: UnitPlate(
                code: '$codePrefix-${(i + 1).toString().padLeft(2, '0')}',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].name, style: techLabel(fontSize: 15)),
                          Text(
                            items[i].id,
                            style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
                          ),
                        ],
                      ),
                    ),
                    RockerToggle(
                      value: items[i].excluded,
                      onChanged: (_) => onToggle(i),
                      tone: RockerTone.caution,
                      labelOn: 'EXCL',
                      labelOff: 'ROUTE',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(LucideIcons.trash2, size: 16, color: CharonColors.muted),
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
