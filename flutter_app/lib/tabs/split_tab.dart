import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../android_channel.dart';
import '../design/design.dart';
import '../split_tunnel.dart';

/// Milestone 7: Applications rules are real on Android (persisted, actually
/// excluded via `VpnService.Builder.addDisallowedApplication` on the next
/// connect - see `CharonVpnService.kt`); Windows app-based exclude remains
/// parked, needs Windows Filtering Platform, which has no turnkey Rust
/// library yet. Domains rules are real on Windows (persisted, resolved to
/// IP/CIDR and bypassed via `tun2proxy`'s `Args::bypass` - see
/// `_resolveBypassCidrs` in `main.dart`); Android doesn't apply them yet
/// this round. Both sections persist rules on both platforms regardless of
/// whether they're applied - see the per-section `note` for what's actually
/// live.
class SplitTab extends StatefulWidget {
  const SplitTab({
    super.key,
    required this.apps,
    required this.onAddApp,
    required this.onToggleApp,
    required this.onRemoveApp,
    required this.domains,
    required this.onAddDomain,
    required this.onToggleDomain,
    required this.onRemoveDomain,
  });

  final List<SplitRule> apps;
  final ValueChanged<SplitRule> onAddApp;
  final ValueChanged<int> onToggleApp;
  final ValueChanged<int> onRemoveApp;

  final List<SplitRule> domains;
  final ValueChanged<SplitRule> onAddDomain;
  final ValueChanged<int> onToggleDomain;
  final ValueChanged<int> onRemoveDomain;

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> {
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

  Future<void> _openAddAppDialog() async {
    if (!Platform.isAndroid) {
      await _openAddDialog(
        title: 'Exclude Application',
        nameLabel: 'Nama app',
        idLabel: 'Package/process name',
        idHint: 'mis. steam.exe',
        onSubmit: widget.onAddApp,
      );
      return;
    }
    List<_InstalledApp> apps;
    try {
      final raw = await androidVpnChannel.invokeMethod<List<Object?>>('listInstalledApps') ?? [];
      apps = raw
          .cast<Map<Object?, Object?>>()
          .map((e) => _InstalledApp(label: e['label'] as String, packageName: e['packageName'] as String))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ambil daftar app: $e')));
      }
      return;
    }
    final excludedIds = widget.apps.map((r) => r.id).toSet();
    if (!mounted) return;
    final result = await showDialog<SplitRule>(
      context: context,
      builder: (context) => _AppPickerDialog(apps: apps, alreadyAdded: excludedIds),
    );
    if (result != null) widget.onAddApp(result);
  }

  Future<void> _openAddDomainDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<SplitRule>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exclude Domain'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Domain atau CIDR',
              hintText: 'mis. weixin.qq.com atau 10.0.0.0/24',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(SplitRule(name: value, id: value, excluded: true));
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (result != null) widget.onAddDomain(result);
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
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final apps = _RuleList(
                heading: 'Applications',
                icon: LucideIcons.laptop,
                codePrefix: 'APP',
                items: widget.apps,
                emptyHint: 'applications',
                note: Platform.isAndroid
                    ? 'Dipilih dari app terinstall. Bakal skip tunnel mulai koneksi berikutnya.'
                    : 'Belum ada mekanismenya di Windows (nunggu Windows Filtering Platform).',
                onAdd: _openAddAppDialog,
                onToggle: widget.onToggleApp,
                onRemove: widget.onRemoveApp,
              );
              final domains = _RuleList(
                heading: 'Domains',
                icon: LucideIcons.globe,
                codePrefix: 'DNS',
                items: widget.domains,
                emptyHint: 'domains',
                note: Platform.isAndroid
                    ? 'Rule kesimpen, belum diterapkan ke tunnel Android sesi ini.'
                    : 'Domain di-resolve ke IP, IP/CIDR literal dipakai langsung — bypass tunnel mulai '
                        'koneksi berikutnya.',
                onAdd: _openAddDomainDialog,
                onToggle: widget.onToggleDomain,
                onRemove: widget.onRemoveDomain,
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
    required this.note,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
  });

  final String heading;
  final IconData icon;
  final String codePrefix;
  final List<SplitRule> items;
  final String emptyHint;
  final String note;
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
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: CharonColors.muted, fontSize: 11)),
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

class _InstalledApp {
  const _InstalledApp({required this.label, required this.packageName});

  final String label;
  final String packageName;
}

/// Searchable picker over launchable apps on the device (Android only - see
/// `MainActivity.kt`'s `listInstalledApps` handler). Replaces manual package
/// name entry now that a real query mechanism exists, unlike the fake static
/// picker in the original Figma Make reference.
class _AppPickerDialog extends StatefulWidget {
  const _AppPickerDialog({required this.apps, required this.alreadyAdded});

  final List<_InstalledApp> apps;
  final Set<String> alreadyAdded;

  @override
  State<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<_AppPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final filtered = widget.apps
        .where((a) => !widget.alreadyAdded.contains(a.packageName))
        .where((a) => a.label.toLowerCase().contains(query) || a.packageName.toLowerCase().contains(query))
        .toList();
    return AlertDialog(
      title: const Text('Exclude Application'),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Cari app', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Nggak ada app cocok', style: TextStyle(color: CharonColors.muted)),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final app = filtered[i];
                        return ListTile(
                          title: Text(app.label),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 11),
                          ),
                          onTap: () => Navigator.of(context).pop(
                            SplitRule(name: app.label, id: app.packageName, excluded: true),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
      ],
    );
  }
}
