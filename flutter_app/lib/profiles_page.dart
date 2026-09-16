import 'dart:convert';

import 'package:flutter/material.dart';

import 'server_profiles.dart';
import 'vless_link.dart';

/// Server profile list + add/edit form. Kept as one file/page since there's
/// nothing else to navigate to yet - splits out once the real UI/UX design
/// lands.
class ProfilesPage extends StatefulWidget {
  final List<ServerProfile> profiles;
  final String? activeId;
  final bool locked;

  const ProfilesPage({
    super.key,
    required this.profiles,
    required this.activeId,
    required this.locked,
  });

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final _store = ProfileStore();
  late List<ServerProfile> _profiles;
  late String? _activeId;

  @override
  void initState() {
    super.initState();
    _profiles = List.of(widget.profiles);
    _activeId = widget.activeId;
  }

  Future<void> _persist() async {
    await _store.save(_profiles, _activeId);
  }

  void _selectActive(String id) {
    if (widget.locked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Disconnect dulu buat ganti server profile aktif.'),
      ));
      return;
    }
    setState(() => _activeId = id);
    _persist();
  }

  Future<void> _delete(ServerProfile profile) async {
    if (profile.id == _activeId && widget.locked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Disconnect dulu buat hapus profile yang lagi aktif.'),
      ));
      return;
    }
    setState(() {
      _profiles.removeWhere((p) => p.id == profile.id);
      if (_activeId == profile.id) {
        _activeId = _profiles.isNotEmpty ? _profiles.first.id : null;
      }
    });
    await _persist();
  }

  Future<void> _openForm({ServerProfile? existing}) async {
    final result = await showDialog<ServerProfile>(
      context: context,
      builder: (context) => _ProfileFormDialog(existing: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _profiles.indexWhere((p) => p.id == result.id);
      if (index >= 0) {
        _profiles[index] = result;
      } else {
        _profiles.add(result);
        _activeId ??= result.id;
      }
    });
    await _persist();
  }

  Future<void> _importFromLink() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import dari vless:// link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'vless://uuid@host:port?...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (link == null || link.trim().isEmpty) return;
    final parsed = profileFromVlessLink(link);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Link vless:// nggak valid.'),
      ));
      return;
    }
    await _openForm(existing: parsed);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Server Profiles'),
          actions: [
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Import dari link vless://',
              onPressed: _importFromLink,
            ),
          ],
        ),
        body: _profiles.isEmpty
            ? const Center(child: Text('Belum ada server profile.'))
            : RadioGroup<String>(
                groupValue: _activeId,
                onChanged: (id) => id == null ? null : _selectActive(id),
                child: ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    final isActive = profile.id == _activeId;
                    return ListTile(
                      leading: Radio<String>(value: profile.id),
                      title: Text(profile.name),
                      subtitle: Text(profile.serverIp),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openForm(existing: profile),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(profile),
                          ),
                        ],
                      ),
                      selected: isActive,
                      onTap: () => _selectActive(profile.id),
                    );
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openForm(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ProfileFormDialog extends StatefulWidget {
  final ServerProfile? existing;

  const _ProfileFormDialog({this.existing});

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _serverIpController =
      TextEditingController(text: widget.existing?.serverIp ?? '');
  late final _configController =
      TextEditingController(text: widget.existing?.configJson ?? '');

  void _tryDetectServerIp() {
    try {
      final data = jsonDecode(_configController.text) as Map<String, dynamic>;
      final outbounds = data['outbounds'] as List;
      final settings =
          (outbounds.first as Map<String, dynamic>)['settings'] as Map<String, dynamic>;
      final vnext = (settings['vnext'] as List).first as Map<String, dynamic>;
      final address = vnext['address'] as String;
      setState(() => _serverIpController.text = address);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nggak bisa deteksi otomatis, isi server IP manual ya.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah Server Profile' : 'Edit Server Profile'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                TextFormField(
                  controller: _configController,
                  decoration: const InputDecoration(
                    labelText: 'Client config JSON (dari server)',
                  ),
                  maxLines: 6,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    try {
                      jsonDecode(v);
                    } catch (_) {
                      return 'Bukan JSON yang valid';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _tryDetectServerIp,
                    child: const Text('Deteksi server IP dari config'),
                  ),
                ),
                TextFormField(
                  controller: _serverIpController,
                  decoration: const InputDecoration(labelText: 'Server IP'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(ServerProfile(
              id: widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              serverIp: _serverIpController.text.trim(),
              configJson: _configController.text.trim(),
            ));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
